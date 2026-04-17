#!/bin/bash

utils::log() {
    local level="$1"
    shift

    local indent="${LOG_INDENT:-0}"
    local message="$*"

    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    local script_name
    script_name="$(basename "$EXECUTABLE")-$$"

    local color_reset="\033[0m"
    local color

    case "$level" in
        INFO)  color="\033[32m" ;;
        WARN)  color="\033[33m" ;;
        ERROR) color="\033[31m" ;;
        *)     color="\033[0m" ;;
    esac

    local padding=""
    if [[ "$indent" -gt 0 ]]; then
        padding="$(printf '%*s' "$indent")"
    fi

    echo -e "${color}[$timestamp] [$script_name] [$level] ${padding}${message}${color_reset}"
}

utils::check_dependencies() {
    local missing=0
    for pkg in passt jq bwrap xdg-dbus-proxy; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            utils::log ERROR "$pkg not installed"
            missing=1
        fi
    done
    return $missing
}

utils::show_usage() {
    cat << EOF
Commands:
    run <program> [args...]
        Run a program inside a sandboxed environment.

    generate [profile]
        Generate symlinks for sandboxed applications.

    list
        List available profiles.

Run options:
    --command <cmd>
        Override the entry command executed inside the sandbox.

    --debug
        Enable execution tracing and debugging envs to retrieve detailed runtime logs to \$HOME/app.trace.

Examples:
    $(basename "$0") run /usr/bin/firefox
    $(basename "$0") run /usr/bin/firefox --debug
    $(basename "$0") run /usr/bin/firefox --command bash -i
    $(basename "$0") generate firefox
    $(basename "$0") generate
EOF
    exit 0
}

utils::dump_vars() {
    local exit_code="${1:-$?}"

    if [[ "$exit_code" -ne 1 ]]; then
        return 0
    fi

    utils::log ERROR "Program exited unexpectedly"
    utils::log INFO "Dumping relevant environment variables:"

    local v

    for v in $(compgen -v); do
        # skip unset variables (safety check)
        [[ -n "${!v+x}" ]] || continue

        # skip exported variables
        case "$(declare -p "$v" 2>/dev/null)" in
            declare\ -x*) continue ;;
        esac

        printf "%s=%q\n" "$v" "${!v}"
    done
}

utils::debug() {
	utils::log INFO "Starting debugging..."

	run_pipeline() {
		local -n _input=$1
		shift

		local -a data=("${_input[@]}")
		local stage
		local start end duration

		declare -A stage_time

		echo "[pipeline] initial input size: ${#data[@]}" >&2

		for stage in "$@"; do
		    local before_count=${#data[@]}

		    start=$EPOCHREALTIME

		    mapfile -t data < <("$stage" "${data[@]}")

		    end=$EPOCHREALTIME
		    duration=$(awk -v s="$start" -v e="$end" \
		    'BEGIN { printf "%.6f", (e - s) * 1000 }')

		    stage_time["$stage"]=$duration

		    local after_count=${#data[@]}

		    echo "[pipeline] stage: $stage" >&2
		    echo "  - time: ${duration}ms" >&2
		    echo "  - items: ${before_count} → ${after_count}" >&2

		    echo "  - sample output:" >&2
		    printf '    %s\n' "${data[@]:0:5}" >&2
		    echo "" >&2
		done

		echo "[pipeline] finished stages: ${#@}" >&2
		printf "%s\n" "${data[@]}"
	}

	ensure_multilib_roots() {
	  local item mode
	  declare -A seen

	  for item in "$@"; do
	    mode="${item%%:*}"

	    # emit original once
	    if [[ -z "${seen[$item]}" ]]; then
	      seen["$item"]=1
	      printf "%s\n" "$item"
	    fi
	  done

	  [[ -e /lib     ]] && printf "%s\n" "/lib"
	  [[ -e /lib64   ]] && printf "%s\n" "/lib64"

	  [[ -e /usr/lib   ]] && printf "%s\n" "/usr/lib"
	  [[ -e /usr/lib64 ]] && printf "%s\n" "/usr/lib64"
	  [[ -e /usr/lib32 ]] && printf "%s\n" "/usr/lib32"
	}

	filter_existing_paths() {
	  local item mode path clean_path
	  local -A seen

	  for item in "$@"; do
	    [[ -z "$item" ]] && continue

	    # Split optional mode prefix (ro:/path or rw:/path)
	    mode="${item%%:*}"
	    path="${item#*:}"

	    if [[ "$path" == "$item" ]]; then
	      clean_path="$item"
	    else
	      clean_path="$path"
	    fi

	    # -----------------------
	    # FAST REJECTS FIRST
	    # -----------------------
	    [[ -z "$clean_path" ]] && continue

	    case "$clean_path" in
	      "/"|"/home"|"/usr/bin/bwrap") continue ;;
	      /proc/*|/dev/*|/sys/*|/sys) continue ;;
	    esac

	    [[ "$item" == "ro:/" || "$item" == "rw:/" ]] && continue

	    # -----------------------
	    # DEPTH CHECK (no awk, no subshell)
	    # -----------------------
	    # count slashes
	    local tmp="${clean_path//[^\/]/}"
	    (( ${#tmp} < 2 )) && continue

	    # -----------------------
	    # DEDUPE EARLY (avoid syscall if already seen)
	    # -----------------------
	    [[ -n "${seen[$clean_path]}" ]] && continue
	    seen["$clean_path"]=1

	    # -----------------------
	    # FILESYSTEM CHECK LAST (expensive)
	    # -----------------------
	    [[ -e "$clean_path" ]] || continue

	    printf "%s\n" "$clean_path"
	  done
	}

	trace_to_raw_paths() {
	  awk '
	  {
	    while (match($0, /\/[a-zA-Z0-9_\/\.\-]+/, m)) {
	      path = m[0]

	      # reject obvious non-path fragments
	      if (path ~ /,/ ) next
	      if (path ~ /=$/ ) next

	      # normalize /newroot or /oldroot
	      sub(/^\/(newroot|oldroot)/, "/", path)

	      # normalize repeated slashes
	      gsub(/\/+/, "/", path)

	      if (path ~ /^\//) {
	        if (!seen[path]++) print path
	      }

	      $0 = substr($0, RSTART + RLENGTH)
	    }
	  }' "$TRACE_FILE"
	}

	add_executable_context_paths() {
	    local base exe home="$HOME"

	    [[ -z "$EXECUTABLE" ]] && {
	        printf "%s\n" "$@"
	        return
	    }

	    base="${EXECUTABLE##*/}"

	    [[ -z "$base" || "$base" == "/" || "$base" == "." ]] && {
	        printf "%s\n" "$@"
	        return
	    }

	    exe="$base"

	    printf "%s\n" "$@"

	    add_if_exists() {
	        local target="$1"
	        local dir file match

	        [[ -z "$target" ]] && return

	        # 1. exact match first (fast path)
	        if [[ -e "$target" ]]; then
	            printf "%s\n" "$target"
	            return
	        fi

	        # 2. case-insensitive fallback (preserves real casing)
	        dir="$(dirname "$target")"
	        file="$(basename "$target")"

	        if [[ -d "$dir" ]]; then
	            match="$(find "$dir" -maxdepth 1 -iname "$file" -print -quit 2>/dev/null)"
	            [[ -n "$match" ]] && printf "%s\n" "$match"
	        fi
	    }

	    add_if_exists "/usr/bin/$exe"
	    add_if_exists "/bin/$exe"
	    add_if_exists "/usr/local/bin/$exe"
	    add_if_exists "/opt/$exe"
	    add_if_exists "/usr/share/$exe"
	    add_if_exists "/usr/share/doc/$exe"
	    add_if_exists "/usr/lib/$exe"
	    add_if_exists "/usr/lib64/$exe"

	    add_if_exists "$home/.config/$exe"
	    add_if_exists "$home/.cache/$exe"
	    add_if_exists "$home/.local/share/$exe"
	}

	isolate_deepest_paths() {
	  local item path mode exe base parent tmp
	  declare -A all_paths
	  declare -A has_children

	  exe="$EXECUTABLE"
	  base="${exe##*/}"

	  # -----------------------------
	  # STEP 1: collect valid paths
	  # -----------------------------
	  for item in "$@"; do
	    [[ -z "$item" ]] && continue

	    mode="${item%%:*}"
	    path="${item#*:}"

	    [[ "$path" == "$item" ]] && path="$item"

	    [[ -z "$path" ]] && continue
	    [[ -e "$path" ]] || continue

	    all_paths["$path"]=1
	  done

	  # ---------------------------------------------------------
	  # STEP 2: mark parents WITHOUT dirname (FAST PATH WALK)
	  # ---------------------------------------------------------
	  for path in "${!all_paths[@]}"; do
	    tmp="$path"

	    # trim upward manually instead of dirname
	    while [[ "$tmp" == */* && "$tmp" != "/" ]]; do
	      tmp="${tmp%/*}"
	      [[ "$tmp" == "" || "$tmp" == "/" ]] && break
	      has_children["$tmp"]=1
	    done
	  done

	  # ---------------------------------------------------------
	  # STEP 3: emit deepest nodes
	  # ---------------------------------------------------------
	  for path in "${!all_paths[@]}"; do

	    if [[ -n "${has_children[$path]}" ]]; then
	      if [[ -d "$path" && "${path##*/}" == "$base" ]]; then
	        :
	      else
	        continue
	      fi
	    fi

	    printf "%s\n" "$path"
	  done
	}

	normalize_paths() {
	  local item mode path IFS='/'
	  local -a parts stack

	  for item in "$@"; do
	    [[ -z $item ]] && continue

	    mode=${item%%:*}
	    path=${item#*:}
	    [[ $path == "$item" ]] && path=$item

	    # -------------------------------
	    # 1. split + normalize in one pass
	    # -------------------------------
	    parts=($path)
	    stack=()

	    for part in "${parts[@]}"; do
	      case "$part" in
	        '' | '.')
	          continue
	          ;;
	        '..')
	          ((${#stack[@]})) && unset 'stack[-1]'
	          ;;
	        *)
	          stack+=("$part")
	          ;;
	      esac
	    done

	    # -------------------------------
	    # 2. rebuild path
	    # -------------------------------
	    if ((${#stack[@]} == 0)); then
	      path="/"
	    else
	      printf -v path '/%s' "${stack[*]}"
	      path=${path// /\/}
	    fi

	    # -------------------------------
	    # 3. reattach mode
	    # -------------------------------
	    printf '%s\n' "${mode:+$mode:}$path"
	  done
	}

	resolve_dependencies() {
	  local item mode path target lib
	  declare -A targets seen

	  local -a unique_targets=()

	  # ---------------------------------------------------------
	  # STEP 1: normalize targets (avoid unnecessary readlink)
	  # ---------------------------------------------------------
	  for item in "$@"; do
	    mode="${item%%:*}"
	    path="${item#*:}"

	    echo "$item"

	    [[ -e "$path" ]] || continue

	    # only resolve if needed (cheap shortcut first)
	    if [[ -L "$path" ]]; then
	      target="$(readlink -f "$path" 2>/dev/null || echo "$path")"
	    else
	      target="$path"
	    fi

	    [[ -z "${targets[$target]}" ]] && {
	      targets["$target"]=1
	      unique_targets+=("$target")
	    }
	  done

	  # ---------------------------------------------------------
	  # STEP 2: dependency extraction (minimize parsing cost)
	  # ---------------------------------------------------------
	  for target in "${unique_targets[@]}"; do

	    # FAST FAIL: skip pseudo / kernel paths early
	    case "$target" in
	      /proc/*|/dev/*|/sys/*|/run/*|/tmp/*) continue ;;
	    esac

	    # run ldd once per unique target
	    while read -r _ _ lib _; do
	      [[ "$lib" != /* ]] && continue

	      # inline dedupe check first
	      [[ -n "${seen[$lib]}" ]] && continue
	      seen["$lib"]=1

	      echo "dep:$lib"
	    done < <(LC_ALL=C ldd "$target" 2>/dev/null)

	  done
	}

	dedupe_paths() {
	  local item mode path key
	  declare -A seen

	  for item in "$@"; do
	    [[ -z "$item" ]] && continue

	    mode="${item%%:*}"
	    path="${item#*:}"
	    [[ "$path" == "$item" ]] && path="$item"

	    # canonical key = ignore mode
	    key="$path"

	    if [[ -z "${seen[$key]}" ]]; then
	      seen["$key"]=1
	      printf '%s\n' "$item"
	    fi
	  done
	}

	collapse_filesystem_roots() {
		  declare -A seen
		  local item path cut_path exe base prefix

		  exe="$EXECUTABLE"
		  base="${exe##*/}"

		  for item in "$@"; do
		    [[ -z $item ]] && continue

		    path="${item#*:}"
		    [[ $path == "$item" ]] && path=$item
		    [[ -z $path || ! -e $path ]] && continue

		    cut_path="$(normalize_paths "$path")"

		    # ALWAYS strip trailing slash for stable keys
		    cut_path="${cut_path%/}"

		    # executable collapse
		    if [[ $cut_path == */"$base"/* ]]; then
		      prefix="${cut_path%%$base*}"
		      prefix="${prefix%/}"
		      cut_path="${prefix}/${base}"
		    fi

			case "$cut_path" in
			  # -------------------------
			  # System libraries
			  # -------------------------
			  /lib/*)        cut_path="/lib" ;;
			  /lib64/*)      cut_path="/lib64" ;;
			  /lib32/*)      cut_path="/lib32" ;;
			  /usr/lib/*)    cut_path="/usr/lib" ;;
			  /usr/lib64/*)  cut_path="/usr/lib64" ;;
			  /usr/lib32/*)  cut_path="/usr/lib32" ;;

			  # -------------------------
			  # TLS / certificates
			  # -------------------------
			  /etc/gnutls/*)                cut_path="/etc/gnutls" ;;
			  /etc/ca-certificates/*)      cut_path="/etc/ca-certificates" ;;
			  /usr/share/ca-certificates/*) cut_path="/usr/share/ca-certificates" ;;

			  # -------------------------
			  # Locale / time / system data
			  # -------------------------
			  /usr/share/locale/*)   cut_path="/usr/share/locale" ;;
			  /usr/share/zoneinfo/*) cut_path="/usr/share/zoneinfo" ;;

			  # -------------------------
			  # Fonts & fontconfig
			  # -------------------------
			  /etc/fonts/*|/etc/fonts/conf.d/*) cut_path="/etc/fonts" ;;
			  /usr/share/fonts/*)               cut_path="/usr/share/fonts" ;;
			  /usr/local/share/fonts/*)         cut_path="/usr/local/share/fonts" ;;
			  /usr/share/fontconfig/*)          cut_path="/usr/share/fontconfig" ;;
			  /var/cache/fontconfig/*)          cut_path="/var/cache/fontconfig" ;;
			  "$HOME/.cache/fontconfig"/*)      cut_path="$HOME/.cache/fontconfig" ;;
			  "$HOME/.fonts"/*)                 cut_path="$HOME/.fonts" ;;

			  # -------------------------
			  # Themes / UI / GTK / icons
			  # -------------------------
			  /usr/share/xkeyboard-config-2/*)         cut_path="/usr/share/xkeyboard-config-2" ;;
			  /usr/share/themes/Default/gtk-3.0/*)     cut_path="/usr/share/themes/Default/gtk-3.0" ;;
			  "$HOME/.themes"/*)                       cut_path="$HOME/.themes" ;;

			  /usr/share/icons/*)                      cut_path="/usr/share/icons" ;;
			  /usr/share/pixmaps/*)                    cut_path="/usr/share/pixmaps" ;;
			  /usr/share/gtk-3.0/*)                    cut_path="/usr/share/gtk-3.0" ;;
			  "$HOME/.icons"/*)                        cut_path="$HOME/.icons" ;;
			  "$HOME/.config/gtk-3.0"/*)               cut_path="$HOME/.config/gtk-3.0" ;;
			  "$HOME/.local/share/icons"/*)            cut_path="$HOME/.local/share/icons" ;;

			  # -------------------------
			  # Graphics stack (Vulkan / Mesa / DRM)
			  # -------------------------
			  /usr/share/vulkan/*)               cut_path="/usr/share/vulkan" ;;
			  "$HOME/.local/share/vulkan"/*)     cut_path="$HOME/.local/share/vulkan" ;;
			  /usr/share/libdrm/*)               cut_path="/usr/share/libdrm" ;;
			  /usr/share/drirc.d/*)              cut_path="/usr/share/drirc.d" ;;
			  /usr/share/glvnd/*)                cut_path="/usr/share/glvnd" ;;

			  # Caches
			  "$HOME/.cache"/*)    cut_path="$HOME/.cache" ;;
			  /var/cache/mesa_shader_cache/*)        cut_path="/var/cache/mesa_shader_cache" ;;

			  # -------------------------
			  # MIME / GLib
			  # -------------------------
			  /usr/share/mime/*)            cut_path="/usr/share/mime" ;;
			  "$HOME/.local/share/mime"/*)  cut_path="$HOME/.local/share/mime" ;;
			  /usr/share/glib-2.0/*)        cut_path="/usr/share/glib-2.0" ;;

			  # -------------------------
			  # Security / credentials
			  # -------------------------
			  "$HOME/.ssh"/*)        cut_path="$HOME/.ssh" ;;
			  "$HOME/.gnupg"/*)      cut_path="$HOME/.gnupg" ;;
			  "$HOME/.pki/nssdb"/*)  cut_path="$HOME/.pki/nssdb" ;;
			esac

		    [[ -z $cut_path || $cut_path == "/" ]] && continue

		    # final stable key (THIS is what fixes your duplicates)
		    local key="$cut_path"

		    if [[ -z ${seen[$key]} ]]; then
		      seen["$key"]=1
		      printf '%s\n' "$cut_path"
		    fi
	  done
	}

	hide_run_runtime_noise() {
	  declare -A seen
	  local item path mode

	  for item in "$@"; do
	    [[ -z "$item" ]] && continue

	    mode="${item%%:*}"
	    path="${item#*:}"

	    [[ "$path" == "$item" ]] && path="$item"
	    [[ -z "$path" ]] && continue

	    # Filter out paths already handled by the wrapper
	    case "$path" in
           /tmp/*)
          	continue
           ;;

	      # ---------------- RUN USER SCOPE ----------------
	      /run/user/*|/run/usr/*)
	        case "$path" in
	          *pulse*|*pipewire*|*alsa*|*jack*|\
	          *wayland*|*x11*|*xorg*|\
	          *dbus*|*bus*|\
	          *.sock|*.socket)
	            continue
	            ;;
	        esac
	        ;;

	      # ---------------- GPU ----------------
	      $HOME/.local/share/vulkan|$HOME/.cache/mesa_shader_cache|/usr/share/drirc.d|\
	      $HOME/.cache/radv_builtin_shaders|/usr/share/libdrm|$HOME/.config/lsfg-vk/conf.toml|\
		  /usr/share/vulkan)
	          continue
	          ;;

	      # ---------------- BINARIES ----------------
	      /usr/bin/xdg-open|/usr/bin/notify-send)
	        continue
	        ;;

		  $HOME/.config/pulse/cookie|$HOME/.pulse-cookie)
			continue
			;;

	      # ---------------- X11 SHARED SOCKETS ----------------
	      /tmp/.X11-unix*|/tmp/.X11±)
	        continue
	        ;;
	    esac

	    # ---------------------------------------------------------
	    # dedupe
	    # ---------------------------------------------------------
	    if [[ -z "${seen[$item]}" ]]; then
	      seen["$item"]=1
	      printf "%s\n" "$item"
	    fi
	  done
	}


	output_json_suggestions() {
	    local item path mode key
	    declare -A groups
	    local -a order all_entries group_sizes

	    while IFS= read -r item; do
	        path="${item#*:}"

	        if [[ -e "$path" && -w "$path" ]]; then
	            mode="rw"
	        else
	            mode="ro"
	        fi

	        path="${path/#$HOME/\$HOME}"

	        if [[ "$path" == \$HOME* ]]; then
	            key="HOME"

	        elif [[ "$path" == /lib || "$path" == /lib64 || "$path" == /lib32 || \
	                "$path" == /usr/lib || "$path" == /usr/lib64 || "$path" == /usr/lib32 ]]; then
	            key="LIB"

	        elif [[ "$path" == /usr/share/* ]]; then
	            key="/usr/share"

	        elif [[ "$path" == /usr/local/* ]]; then
	            key="/usr/local"

	        elif [[ "$path" == /usr/bin/* || "$path" == /usr/sbin/* ]]; then
	            key="/usr/bin"

	        else
	            key="/$(cut -d/ -f2 <<< "$path")"
	        fi

	        [[ -z "${groups[$key]+x}" ]] && order+=("$key")
	        groups["$key"]+=$'\n'"$mode:$path"

	    done < <(printf "%s\n" "$@")

	    for key in "${order[@]}"; do
	        local count=0
	        while IFS= read -r entry; do
	            [[ -z "$entry" ]] && continue
	            all_entries+=("$entry")
	            ((count++))
	        done <<< "${groups[$key]}"
	        group_sizes+=("$count")
	    done

	    echo "["

	    local total=${#all_entries[@]}

	    for i in "${!all_entries[@]}"; do
	        if [[ $i -eq $((total - 1)) ]]; then
	            printf '  "%s"\n' "${all_entries[i]}"
	        else
	            printf '  "%s",\n' "${all_entries[i]}"
	        fi

	        local running=0
	        for g in "${group_sizes[@]}"; do
	            running=$((running + g))
	            if [[ $i -eq $((running - 1)) && $i -ne $((total - 1)) ]]; then
	                echo ""
	            fi
	        done
	    done

	    echo "]"
	}

	# =========================================================
	# PIPELINE EXECUTION
	# =========================================================

	local -a items=()

	mapfile -t items < <(
		run_pipeline items \
			trace_to_raw_paths \
			add_executable_context_paths \
			resolve_dependencies \
			normalize_paths \
			filter_existing_paths \
			isolate_deepest_paths \
			collapse_filesystem_roots \
			hide_run_runtime_noise \
			ensure_multilib_roots \
			dedupe_paths
	)

	# =========================================================
	# OUTPUT
	# =========================================================
	if [[ "${#items[@]}" -eq 0 ]]; then
		utils::log "debug_build_json_suggestions: no recommendations found"
		return 0
	fi

	echo ""

	utils::log WARN "This dataset comes from strace output, so it includes a lot of paths that the program probably doesn’t actually need."
	utils::log WARN "Expect noise from runtime stuff, debug leftovers, and indirect access patterns."
	utils::log WARN "You should heavily filter out anything sensitive or internal (like /proc, /sys, /dev, /run, sockets, caches, credentials)."
	utils::log WARN "Also keep in mind it can miss important things the program actually needs to run, like binaries or shared libs (e.g. /usr/bin)."
	utils::log WARN "Just because a path shows up doesn’t mean it’s required—and just because it doesn’t show up doesn’t mean it isn’t required."
	utils::log INFO "Profile recommendation:"
	output_json_suggestions "${items[@]}"
}

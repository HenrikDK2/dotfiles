#!/bin/bash

trap utils::cleanup EXIT INT TERM

PROXY_SOCKET="${XDG_RUNTIME_DIR}/bus-proxy-$(uuidgen).sock"
DEBUG=0

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
	INFO) color="\033[32m" ;;
	WARN) color="\033[33m" ;;
	ERROR) color="\033[31m" ;;
	*) color="\033[0m" ;;
	esac

	local padding=""
	if [[ "$indent" -gt 0 ]]; then
		padding="$(printf '%*s' "$indent")"
	fi

	echo -e "${color}[$timestamp] [$script_name] [$level] ${padding}${message}${color_reset}"
}

utils::dbus() {
	if [[ ${#DBUS_PORTALS[@]} -eq 0 ]]; then
		utils::log INFO "DBUS_PORTALS is empty, skipping DBus proxy"
		return 0
	fi

	utils::log INFO "Starting DBus proxy..."
	LOG=; [[ ${DEBUG:-0} == 1 ]] && LOG=--log
	xdg-dbus-proxy "$DBUS_SESSION_BUS_ADDRESS" "$PROXY_SOCKET" \
		"${DBUS_PORTALS[@]}" --filter &

	PROXY_PID=$!
	utils::log INFO "Waiting for proxy socket..."
	while [[ ! -S "$PROXY_SOCKET" ]]; do sleep 0.01; done
	utils::log INFO "Proxy ready"

	# Required for dbus proxy
	BWRAP_ARGS+=(
		"--dev-bind-try" "$PROXY_SOCKET" "$PROXY_SOCKET"
		"--dev-bind-try" "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/bus"
		
		"--setenv" "DBUS_SESSION_BUS_ADDRESS" "unix:path=$PROXY_SOCKET"
		"--setenv" "XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR"
		"--setenv" "XDG_SESSION_TYPE" "$XDG_SESSION_TYPE"
		"--setenv" "XDG_CURRENT_DESKTOP" "$XDG_CURRENT_DESKTOP"
		"--setenv" "XDG_BACKEND" "$XDG_BACKEND"
	)
}

utils::run() {
	if [[ "${1:-}" == "--debug" ]]; then
		DEBUG=1
		shift
	fi

	utils::dbus
	utils::log INFO "Launching $EXECUTABLE..."

	# Filter out unwanted bwrap flag
	CLEAN_BWRAP_ARGS=()
	for arg in "${BWRAP_ARGS[@]}"; do
		# For some reason causes issues with Firefox
		# Not a problem since the cleanup function takes care of it
		if [[ "$arg" != "--die-with-parent" ]]; then
			CLEAN_BWRAP_ARGS+=("$arg")
		fi
	done

	if [[ "$DEBUG" -eq 1 ]]; then
		strace -f -tt -s 128 -e trace=all -o "$TRACE_FILE" \
			bwrap "${CLEAN_BWRAP_ARGS[@]}" "$EXECUTABLE" "$@"
	else
		bwrap "${CLEAN_BWRAP_ARGS[@]}" "$EXECUTABLE" "$@"
	fi

	EXIT_CODE=$?
	exit $EXIT_CODE
}

utils::cleanup() {
	utils::log INFO "Cleaning up..."

	if [ "$DEBUG" -eq 1 ]; then
		utils::debug
	fi

	if [[ -n "${PROXY_PID:-}" ]] && kill -0 "$PROXY_PID" 2>/dev/null; then
		kill "$PROXY_PID" 2>/dev/null || true
	fi

	rm -f "$PROXY_SOCKET"
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
			if [[ -z "${seen[$item]+x}" ]]; then
				seen["$item"]=1
				printf "%s\n" "$item"
			fi
		done

		[[ -e /lib ]] && printf "%s\n" "/lib"
		[[ -e /lib64 ]] && printf "%s\n" "/lib64"

		[[ -e /usr/lib ]] && printf "%s\n" "/usr/lib"
		[[ -e /usr/lib64 ]] && printf "%s\n" "/usr/lib64"
		[[ -e /usr/lib32 ]] && printf "%s\n" "/usr/lib32"
	}

	add_env() {
		local -a out=("$@")
		local item
		declare -A seen

		emit() {
		    local var="$1"
		    local value="$2"

		    # Check if variable exists (is set)
		    if [[ -z "${!var+x}" ]]; then
		        return
		    fi

		    [[ -z "${seen[$var]+x}" ]] && {
		        seen["$var"]=1
		        out+=("--setenv" "$var" "$value")
		    }
		}

		for item in "$@"; do
			case "$item" in

				*wayland*)
					emit "WAYLAND_DISPLAY" "\$WAYLAND_DISPLAY"
					emit "DISPLAY" "\$DISPLAY"
					;;

				/tmp/.X11-unix*|/tmp/.X11-unix/*|/tmp/.X11-unix/X*|*x11*)
					emit "DISPLAY" "\$DISPLAY"
					emit "XAUTHORITY" "\$XAUTHORITY"
					;;

				/home/*)
					emit "HOME" "\$HOME"
					;;

			esac
		done

		printf "%s\n" "${out[@]}"
	}

	pipewire_enrichment() {
		local item

		set -f

		for item in "$@"; do
			printf '%s\n' "$item"
			[[ "$item" == *pipewire* ]] && pipewire_detected=1
		done

		set +f

		[[ "${pipewire_detected:-0}" -eq 1 && -n "$XDG_RUNTIME_DIR" ]] && {
			printf '%s\n' \
				"$XDG_RUNTIME_DIR/pipewire-0" \
				"/usr/share/pipewire"
		}
	}

	gpu_device_enrichment() {
		local item
		local -a out=()
		local gpu_detected=0

		# Disable globbing safely (local -o noglob is not valid in bash)
		set -f

		# detect GPU-related access patterns
		for item in "$@"; do
			case "$item" in
			/dev/nvidia* | \
				/dev/kfd* | \
				/dev/dri* | \
				/sys/class/drm* | \
				/sys/dev/char* | \
				/sys/devices/pci* | \
				/sys/bus/pci*)
				gpu_detected=1
				;;
			esac

			out+=("$item")
		done

		# re-enable globbing
		set +f

		# inject full GPU stack if any GPU path was seen
		if [[ "$gpu_detected" -eq 1 ]]; then
			out+=(
				"/dev/nvidia"
				"/dev/kfd"
				"/dev/dri"
				"/sys/class/drm"
				"/sys/dev/char"
				"/sys/devices"
			)
		fi

		printf "%s\n" "${out[@]}"
	}

	filter_existing_paths() {
		local item mode path clean_path
		local -A seen

		for item in "$@"; do
			[[ -z "$item" ]] && continue

			mode="${item%%:*}"
			path="${item#*:}"

			if [[ "$path" == "$item" ]]; then
				clean_path="$item"
			else
				clean_path="$path"
			fi

			# -----------------------
			# FAST REJECTS
			# -----------------------
			[[ -z "$clean_path" ]] && continue

			case "$clean_path" in
				/home | /usr/bin/bwrap | \
				/ | /root* | /newroot* | /oldroot* | \
			    /proc* | /dev/core* | /dev/fd* | \
				/dev/console | /dev/full | /dev/null | \
				/dev/nvme* | \
				/dev/pts* | /dev/ptmx | /dev/random | \
				/dev/stdin | /dev/stdout | /dev/stderr | \
				/dev/tty | \
				/dev/udmabuf | /dev/urandom | /dev/zero | \
				/run/dbus/system_bus_socket | /run/user/1000/bus-proxy*) # Managed by proxy dbus
				continue
				;;
			esac

			# -----------------------
			# DEDUPE EARLY
			# -----------------------
			if [[ -z "${seen[$clean_path]+x}" ]]; then
				seen["$clean_path"]=1
			else
				continue
			fi

			# -----------------------
			# FILE EXISTS CHECK
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

			if [[ -n "${has_children[$path]+x}" ]]; then
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

			if [[ -z "${targets[$target]+x}" ]]; then
				targets["$target"]=1
				unique_targets+=("$target")
			fi
		done

		# ---------------------------------------------------------
		# STEP 2: dependency extraction (minimize parsing cost)
		# ---------------------------------------------------------
		for target in "${unique_targets[@]}"; do

			# FAST FAIL: skip pseudo / kernel paths early
			case "$target" in
			/proc/* | /dev/* | /sys/* | /run/* | /tmp/*) continue ;;
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

			if [[ -z "${seen[$key]+x}" ]]; then
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
			# System libraries
			/lib/*) cut_path="/lib" ;;
			/lib64/*) cut_path="/lib64" ;;
			/lib32/*) cut_path="/lib32" ;;
			/usr/lib/*) cut_path="/usr/lib" ;;
			/usr/lib64/*) cut_path="/usr/lib64" ;;
			/usr/lib32/*) cut_path="/usr/lib32" ;;

			# TLS / certificates
			/etc/gnutls/*) cut_path="/etc/gnutls" ;;
			/etc/ca-certificates/*) cut_path="/etc/ca-certificates" ;;
			/usr/share/ca-certificates/*) cut_path="/usr/share/ca-certificates" ;;

			# Locale / time / system data
			/usr/share/locale/*) cut_path="/usr/share/locale" ;;
			/usr/share/zoneinfo/*) cut_path="/usr/share/zoneinfo" ;;

			# Fonts & fontconfig
			/etc/fonts/* | /etc/fonts/conf.d/*) cut_path="/etc/fonts" ;;
			/usr/share/fonts/*) cut_path="/usr/share/fonts" ;;
			/usr/local/share/fonts/*) cut_path="/usr/local/share/fonts" ;;
			/usr/share/fontconfig/*) cut_path="/usr/share/fontconfig" ;;
			/var/cache/fontconfig/*) cut_path="/var/cache/fontconfig" ;;
			"$HOME/.cache/fontconfig"/*) cut_path="$HOME/.cache/fontconfig" ;;
			"$HOME/.fonts"/*) cut_path="$HOME/.fonts" ;;

			# Themes / UI / GTK / icons / misc
			/usr/share/xkeyboard-config-2/*) cut_path="/usr/share/xkeyboard-config-2" ;;
			/usr/share/themes/Default/gtk-3.0/*) cut_path="/usr/share/themes/Default/gtk-3.0" ;;
			"$HOME/.themes"/*) cut_path="$HOME/.themes" ;;

			/usr/share/icons/*) cut_path="/usr/share/icons" ;;
			/usr/share/pixmaps/*) cut_path="/usr/share/pixmaps" ;;
			/usr/share/gtk-3.0/*) cut_path="/usr/share/gtk-3.0" ;;
			"$HOME/.icons"/*) cut_path="$HOME/.icons" ;;
			"$HOME/.config/gtk-3.0"/*) cut_path="$HOME/.config/gtk-3.0" ;;
			"$HOME/.local/share/icons"/*) cut_path="$HOME/.local/share/icons" ;;
			"$HOME/.local/share/gvfs-metadata"/*) cut_path="$HOME/.local/share/gvfs-metadata" ;;
			/usr/share/alsa/*) cut_path="/usr/share/alsa" ;;


			# Graphics stack (Vulkan / Mesa / DRM)
			/usr/share/vulkan/*) cut_path="/usr/share/vulkan" ;;
			"$HOME/.local/share/vulkan"/*) cut_path="$HOME/.local/share/vulkan" ;;
			/usr/share/libdrm/*) cut_path="/usr/share/libdrm" ;;
			/usr/share/drirc.d/*) cut_path="/usr/share/drirc.d" ;;
			/usr/share/glvnd/*) cut_path="/usr/share/glvnd" ;;

			# Caches
			"$HOME/.cache"/*) cut_path="$HOME/.cache" ;;
			/var/cache/mesa_shader_cache/*) cut_path="/var/cache/mesa_shader_cache" ;;

			# MIME / GLib
			/usr/share/mime/*) cut_path="/usr/share/mime" ;;
			"$HOME/.local/share/mime"/*) cut_path="$HOME/.local/share/mime" ;;
			/usr/share/glib-2.0/*) cut_path="/usr/share/glib-2.0" ;;

			# Applications
			$HOME/.local/share/Steam/*) cut_path="$HOME/.local/share/Steam" ;;
			$HOME/.steam/*) cut_path="$HOME/.steam" ;;
			/usr/share/steam/compatibilitytools.d*) cut_path="/usr/share/steam/compatibilitytools.d" ;;

			# /sys & /dev calls
			/sys/devices*) cut_path="/sys/devices" ;;
			/dev/dri/*) cut_path="/sys/dri" ;;

			# Security / credentials
			"$HOME/.ssh"/*) cut_path="$HOME/.ssh" ;;
			"$HOME/.gnupg"/*) cut_path="$HOME/.gnupg" ;;
			"$HOME/.pki/nssdb"/*) cut_path="$HOME/.pki/nssdb" ;;
			esac

			[[ -z $cut_path || $cut_path == "/" ]] && continue

			# final stable key (THIS is what fixes your duplicates)
			local key="$cut_path"

			if [[ -z ${seen[$key]+x} ]]; then
				seen["$key"]=1
				printf '%s\n' "$cut_path"
			fi
		done
	}

	copy_to_clipboard() {
		if command -v wl-copy >/dev/null 2>&1; then
			wl-copy
		elif command -v xclip >/dev/null 2>&1; then
			xclip -selection clipboard
		elif command -v xsel >/dev/null 2>&1; then
			xsel --clipboard --input
		elif command -v pbcopy >/dev/null 2>&1; then
			pbcopy
		else
			utils::log WARN "No clipboard tool found (wl-copy/xclip/xsel/pbcopy)"
		fi
	}

	print_output() {
		local -a input=("$@")

		local -a paths=()
		local -a env_list=()

		local i item

		# =====================================================
		# 1. Split input into paths vs env (--setenv triplets)
		# =====================================================
		for ((i = 0; i < ${#input[@]}; i++)); do
			item="${input[i]}"
			[[ -z "$item" ]] && continue

			if [[ "$item" == "--setenv" ]]; then
				# expect: --setenv VAR VALUE
				env_list+=("--setenv:${input[i+1]}:${input[i+2]}")
				((i += 2))
				continue
			fi

			paths+=("$item")
		done

		# =====================================================
		# 2. Sort + dedupe paths (unchanged logic)
		# =====================================================
		local -a sorted
		mapfile -t sorted < <(
			printf "%s\n" "${paths[@]}" |
				sed 's|^[^:]*:||' |
				sort -u
		)

		declare -A seen
		local -a rw_list=()
		local -a ro_list=()
		local -a dev_list=()

		local path

		for path in "${sorted[@]}"; do
			[[ -z "$path" ]] && continue
			[[ -n "${seen[$path]+x}" ]] && continue
			seen["$path"]=1

			if [[ "$path" == /dev/* || "$path" == /run* ]]; then
				dev_list+=("$path")
				continue
			fi

			if [[ -e "$path" && -w "$path" ]]; then
				rw_list+=("$path")
			else
				ro_list+=("$path")
			fi
		done

		# =====================================================
		# 3. Helpers
		# =====================================================
		get_root() {
			local p="$1"
			echo "$p" | awk -F/ 'NF>=2 {print "/" $2}'
		}

		print_path() {
			local cmd="$1"
			local p="$2"

			# ---- ENV FORMAT ----
			if [[ "$cmd" == "--setenv" ]]; then
				local var val
				IFS=':' read -r _ var val <<< "$p"
				val="${val//\\$/\$}"
				printf -- "--setenv %s %s\n" "$var" "$val"
				return
			fi

			# ---- PATH FORMAT ----
			local out="$p"
			[[ "$p" == "$HOME"* ]] && out="\$HOME${p#$HOME}"
			printf -- "%s %s %s\n" "$cmd" "$out" "$out"
		}

		print_block() {
			local -n arr="$1"
			local cmd="$2"
			local prev_root=""
			local root
			local p

			for p in "${arr[@]}"; do
				[[ -z "$p" ]] && continue

				root=$(get_root "$p")

				if [[ "$root" != "$prev_root" ]]; then
					[[ -n "$prev_root" ]] && printf "\n"
					prev_root="$root"
				fi

				print_path "$cmd" "$p"
			done
		}

		# =====================================================
		# 4. OUTPUT BLOCKS (including envs)
		# =====================================================
		print_block rw_list "--bind-try"
		print_block ro_list "--ro-bind-try"
		print_block dev_list "--dev-bind-try"

		echo ""

		print_block env_list "--setenv"
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
			isolate_deepest_paths \
			gpu_device_enrichment \
			pipewire_enrichment \
			filter_existing_paths \
			collapse_filesystem_roots \
			ensure_multilib_roots \
			dedupe_paths \
			add_env
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
	print_output "${items[@]}" 2>/dev/null | tee >(copy_to_clipboard) $HOME/bwrap-profile.txt
	echo
	utils::log INFO "*Copied to clipboard* - also saved in $HOME/bwrap-profile.txt"
}

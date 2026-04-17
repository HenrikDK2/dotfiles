#!/bin/bash

utils::log() {
    local level="$1"
    shift
    local message="$*"

    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local script_name="$(basename "$EXECUTABLE")-$$"
    local color_reset="\033[0m"
    local color

    case "$level" in
        INFO)
            color="\033[32m"
            ;;
        WARN)
            color="\033[33m"
            ;;
        ERROR)
            color="\033[31m"
            ;;
        *)
            color="\033[0m"
            ;;
    esac

    echo -e "${color}[$timestamp] [$script_name] [$level] $message${color_reset}"
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

utils::print_ldd() {
    local ldd_output="$(ldd "$EXECUTABLE" 2>&1)"

    # only log if it's a dynamic executable
    if [[ "$ldd_output" != *"not a dynamic executable"* ]]; then
        echo -e ""
        utils::log INFO "ldd output for $EXECUTABLE"

        # extract unique library paths
        local libs
        libs=$(printf '%s\n' "$ldd_output" \
            | awk '/=>/ {print $3} /^[^ ]/ {print $1}' \
            | grep '^/' \
            | sort -u)

        # group into unique folders
        local dirs
        dirs=$(printf '%s\n' "$libs" \
            | xargs -n1 dirname \
            | sort -u)

        utils::log INFO "Detected required directories:"

        # print nicely, one per line
        while IFS= read -r dir; do
            utils::log INFO "  - $dir"
        done <<< "$dirs"

        utils::log INFO "Consider adding them\n"
    fi
}

utils::debug_build_json_suggestions() {
    run_pipeline() {
        local -n _input=$1
        shift

        local -a data=("${_input[@]}")
        local stage

        for stage in "$@"; do
            mapfile -t data < <("$stage" "${data[@]}")
        done

        printf "%s\n" "${data[@]}"
    }

    resolve_path() {
        local p="$1"
        p="${p//\/\//\/}"

        [[ "$p" == /XXX* ]] && return 1
        [[ "$p" == "/" ]] && return 1

        echo "$p"
    }

    home_remap() {
        local p="$1"

        if [[ "$p" =~ ^/\.[^/]+ ]]; then
            local candidate="$HOME$p"
            [[ -e "$candidate" ]] || return 1
            echo "\$HOME$p"
            return 0
        fi

        echo "$p"
    }

    normalize_path() {
        local p="$1"
        p="$(resolve_path "$p")" || return 1
        p="$(home_remap "$p")" || return 1
        echo "$p"
    }

    extract_path() {
        grep -oE '/[^[:space:]]+' <<< "$1" | head -n1
    }

    classify_mode() {
        local line="$1"
        local syscall="${line%% *}"
        local mode="ro"

        if [[ "$line" == *"ENOENT"* || "$line" == *"ENOTDIR"* || \
              "$line" == *"EACCES"* || "$line" == *"EPERM"* ]]; then
            mode="rw"
        fi

        if [[ "$syscall" == "execve" || "$syscall" == "dlopen" ]]; then
            mode="ro"
        fi

        echo "$mode"
    }

    is_allowed_path() {
        local path="$1"

        case "$path" in
            /|/var|/dev|/bin|/sbin|/lib|/etc|/usr|/opt|/tmp|/run|/home) return 1 ;;
            /tmp/.mount*|/tmp/.mount/*|/newroot/*|/oldroot/*|/dev/tty) return 1 ;;
        esac

        return 0
    }

    parse_groups() {
        local b line path

        for b in $(printf '%s\n' "${!groups[@]}" | sort); do
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                path="$(extract_path "$line")"
                [[ -z "$path" ]] && continue
                echo "raw:$line|$path"
            done <<< "${groups[$b]}"
        done
    }

    normalize_stage() {
        local item path

        for item in "$@"; do
            path="${item#*|}"
            path="$(normalize_path "$path")" || continue
            echo "${item%%|*}:$path"
        done
    }

    classify_stage() {
        local item line path mode

        for item in "$@"; do
            line="${item#*:}"
            path="${item##*:}"

            mode="$(classify_mode "$line")"
            echo "$mode:$path"
        done
    }

    resolve_dependencies() {
        local item real lib key
        declare -A seen

        for item in "$@"; do
            echo "$item"

            real="${item#*:}"
            real="${real/#\~/$HOME}"
            real="${real//\$HOME/$HOME}"

            [[ -f "$real" ]] || continue
            file "$real" 2>/dev/null | grep -q "ELF" || continue

            while IFS= read -r line; do
                lib="$(awk '{for(i=1;i<=NF;i++) if ($i ~ /^\//) {print $i; exit}}' <<< "$line")"
                [[ -z "$lib" || ! -e "$lib" ]] && continue

                key="ro:$lib"
                [[ -n "${seen[$key]}" ]] && continue
                seen["$key"]=1

                echo "$key"
            done < <(ldd "$real" 2>/dev/null)
        done
    }

    filter_paths() {
        local item path real

        for item in "$@"; do
            path="${item#*:}"

            # normalize HOME
            real="${path/#\~/$HOME}"
            real="${real//\$HOME/$HOME}"

            # -----------------------------------------------------
            # 1. must exist on filesystem
            # -----------------------------------------------------
            [[ -e "$real" ]] || continue

            # -----------------------------------------------------
            # 2. must not be blocked by policy rules
            # -----------------------------------------------------
            is_allowed_path "$path" || continue

            echo "$item"
        done
    }

    select_deepest_only() {
        local -a arr=("$@")
        local i j a b

        for i in "${!arr[@]}"; do
            a="${arr[$i]#*:}"

            for j in "${!arr[@]}"; do
                b="${arr[$j]#*:}"

                [[ "$a" == "$b" ]] && continue

                if [[ "$b" == "$a/"* ]]; then
                    unset 'arr[$i]'
                    break
                fi
            done
        done

        printf "%s\n" "${arr[@]}"
    }

    collapse_items() {
        local item path dir
        declare -A groups

        for item in "$@"; do
            path="${item#*:}"
            dir="$(dirname "$path")"
            groups["$dir"]+="$item"$'\n'
        done

        for dir in "${!groups[@]}"; do
            while IFS= read -r item; do
                [[ -n "$item" ]] && echo "$item"
            done <<< "${groups[$dir]}"
        done
    }

    collapse_whitelisted_folders() {
        local item path w root key prefix
        local -a WHITELIST=("themes" ".cursors" ".themes" "fonts" ".icons" "fontconfig" "icons" ".fontconfig")

        declare -A group_count
        declare -A emitted

        # ---------------------------------------------------------
        # STEP 1: COUNT PREFIX GROUPS
        # ---------------------------------------------------------
        for item in "$@"; do
            path="${item#*:}"

            for w in "${WHITELIST[@]}"; do

                # match directory boundary properly
                if [[ "$path" == *"/$w/"* || "$path" == *"/$w"* ]]; then

                    # normalize root up to whitelist segment
                    root="${path%%/$w*}"
                    key="$root/$w"

                    group_count["$key"]=$((group_count["$key"] + 1))
                fi
            done
        done

        # ---------------------------------------------------------
        # STEP 2: EMIT COLLAPSED OR RAW
        # ---------------------------------------------------------
        for item in "$@"; do
            path="${item#*:}"
            local collapsed=0

            for w in "${WHITELIST[@]}"; do

                if [[ "$path" == *"/$w/"* || "$path" == *"/$w"* ]]; then

                    root="${path%%/$w*}"
                    key="$root/$w"

                    # collapse condition
                    if [[ "${group_count[$key]}" -gt 1 ]]; then
                        if [[ -z "${emitted[$key]}" ]]; then
                            echo "$key"
                            emitted["$key"]=1
                        fi
                        collapsed=1
                    fi

                    break
                fi
            done

            # not part of whitelist collapse → keep original
            [[ "$collapsed" -eq 0 ]] && echo "$item"
        done
    }

    dedupe_paths_exact() {
        local item
        declare -A seen

        for item in "$@"; do
            [[ -n "${seen[$item]}" ]] && continue
            seen["$item"]=1
            echo "$item"
        done
    }

    filter_existing_profile_paths() {
        local item path real parent
        declare -A profile

        while IFS= read -r entry; do
            path="${entry#*:}"
            path="${path/#\~/$HOME}"
            path="${path//\$HOME/$HOME}"
            profile["$path"]=1
        done < <(jq -r '.paths[]?' <<< "$PROFILE_JSON")

        for item in "$@"; do
            path="${item#*:}"
            real="${path/#\~/$HOME}"
            real="${real//\$HOME/$HOME}"

            [[ -n "${profile[$real]}" ]] && continue

            parent="$real"
            while [[ "$parent" != "/" ]]; do
                parent="$(dirname "$parent")"
                [[ -n "${profile[$parent]}" ]] && continue 2
            done

            echo "$item"
        done
    }

    output_json_suggestions() {
        local item path mode key
        declare -A groups
        local -a order
        local -a entries

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
            elif [[ "$path" == /usr/share/* ]]; then
                key="/usr/share"
            else
                key="/$(echo "$path" | cut -d/ -f2)"
            fi

            if [[ -z "${groups[$key]+x}" ]]; then
                order+=("$key")
            fi

            groups["$key"]+=$'\n'"$mode:$path"

        done < <(printf "%s\n" "$@")

        # build ordered list while preserving group separation
        local -a all_entries
        local -a group_sizes

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

            # add blank line after each group (except last group boundary)
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

	enforce_single_path_per_subtree() {
	    local -a input=("$@")
	    local -a out=()

	    local i j a b

	    # normalize helper
	    norm() {
	        local p="$1"
	        p="${p/#\$HOME/$HOME}"
	        echo "$p"
	    }

	    for i in "${!input[@]}"; do
	        a="${input[$i]#*:}"
	        a="$(norm "$a")"

	        local keep=1

	        for j in "${!input[@]}"; do
	            [[ "$i" == "$j" ]] && continue

	            b="${input[$j]#*:}"
	            b="$(norm "$b")"

	            # CASE 1: a is inside b → drop a
	            if [[ "$a" == "$b/"* ]]; then
	                keep=0
	                break
	            fi

	            # CASE 2: b is inside a → drop b (optional but stabilizes output)
	            if [[ "$b" == "$a/"* ]]; then
	                continue 2
	            fi
	        done

	        [[ "$keep" -eq 1 ]] && out+=("${input[$i]}")
	    done

	    printf "%s\n" "${out[@]}"
	}

	merge_profile_and_pipeline_paths() {
	    local item mode path real

	    declare -A seen

	    # ---------------------------------------------------------
	    # 1. runtime input first
	    # ---------------------------------------------------------
	    for item in "$@"; do
	        echo "$item"
	        seen["$item"]=1
	    done

	    # ---------------------------------------------------------
	    # 2. inject profile paths AFTER runtime
	    # ---------------------------------------------------------
	    while IFS= read -r item; do
	        [[ -z "$item" ]] && continue

	        mode="${item%%:*}"
	        path="${item#*:}"

	        path="${path/#\$HOME/$HOME}"
	        path="${path/#\~/$HOME}"

	        real="$mode:$path"

	        [[ -n "${seen[$real]}" ]] && continue
	        seen["$real"]=1

	        echo "$real"
	    done < <(jq -r '.paths[]?' <<< "$PROFILE_JSON")
	}

    # =========================================================
    # PIPELINE EXECUTION
    # =========================================================
    local -a items=()

	mapfile -t items < <(
	    run_pipeline items \
	        parse_groups \
	        normalize_stage \
	        classify_stage \
	        resolve_dependencies \
	        filter_paths \
	        collapse_whitelisted_folders \
			merge_profile_and_pipeline_paths \
	        dedupe_paths_exact \
	        enforce_single_path_per_subtree \
	)

	# =========================================================
	# EMPTY RESULT GUARD (WITH UTILS LOG)
	# =========================================================
	if [[ "${#items[@]}" -eq 0 ]]; then
	    utils::log "debug_build_json_suggestions: no recommendations found"
	    return 0
	fi

	echo -e ""
	utils::log INFO "Profile recommendation:"

	output_json_suggestions "${items[@]}"
}

utils::debug() {
    [[ ! -f "$TRACE_FILE" ]] && return 0

    if [[ -n "${DEBUG_INIT:-}" ]]; then
        return 0
    fi

    utils::log INFO "Starting debugging..."
    utils::log INFO "Analyzing trace file: $TRACE_FILE"

    # =========================================================
    # CAPTURE ALL FAILURES
    # =========================================================
    mapfile -t failed_lines < <(
        grep -E "=[[:space:]]*-1[[:space:]]+[A-Z0-9_]+" "$TRACE_FILE" \
        | grep -v "EINVAL"
    )

    if (( ${#failed_lines[@]} == 0 )); then
        utils::log INFO "No syscall errors detected"
        TRACE_ANALYZED=1
        return 0
    fi

    # =========================================================
    # STRUCTURED PARSING (KEEP ALL EVENTS)
    # =========================================================
    mapfile -t failed_structured < <(
        printf '%s\n' "${failed_lines[@]}" | awk '
        function bucket(p) {
            if (p == "") return "NO_PATH"
            if (p ~ "^/usr/share") return "/usr/share"
            if (p ~ "^/usr/local/share") return "/usr/local/share"
            if (p ~ "^/usr") return "/usr"
            if (p ~ "^/var") return "/var"
            if (p ~ "^/etc") return "/etc"
            if (p ~ "^/lib") return "/lib"
            if (p ~ "^/bin") return "/bin"
            split(p, a, "/")
            return "/" a[2]
        }

        {
            syscall = ""
            err = ""
            path = ""

            if (match($0, /^([a-zA-Z0-9_]+)\(/, m)) {
                syscall = m[1]
            }

            if (match($0, /= *-1 +([A-Z0-9_]+)/, e)) {
                err = e[1]
            }

            if (match($0, /"\/[^"]+"/)) {
                path = substr($0, RSTART+1, RLENGTH-2)
            }

            # normalize ONLY for grouping
            npath = path
            gsub(/\/+/, "/", npath)

            g = bucket(npath)

            print g "\t" syscall "\t" err "\t" path
        }'
    )

    # =========================================================
    # GROUP OUTPUT BY SUBTREE
    # =========================================================
    declare -A groups

    for line in "${failed_structured[@]}"; do
        IFS=$'\t' read -r bucket syscall err path <<< "$line"
        [[ -z "$syscall" || -z "$err" ]] && continue

        groups["$bucket"]+="$syscall $err -> $path"$'\n'
    done

    # =========================================================
    # PRINT RESULTS
    # =========================================================
    for b in $(printf '%s\n' "${!groups[@]}" | sort); do
        utils::log WARN "==================== $b ===================="
        while IFS= read -r line; do
            [[ -n "$line" ]] && utils::log WARN "$line"
        done <<< "${groups[$b]}"
    done

	utils::debug_build_json_suggestions
	TRACE_ANALYZED=1
}

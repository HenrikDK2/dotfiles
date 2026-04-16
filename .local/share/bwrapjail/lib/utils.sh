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

    --trace
        Enable execution tracing and write detailed runtime logs to \$HOME/sandbox-trace.log.

Examples:
    $(basename "$0") run /usr/bin/firefox
    $(basename "$0") run /usr/bin/firefox --trace
    $(basename "$0") run /usr/bin/firefox --command /usr/bin/alacritty
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

utils::analyze_trace() {
    [[ ! -f "$TRACE_FILE" ]] && return 0

    if [[ -n "${TRACE_ANALYZED:-}" ]]; then
        return 0
    fi

    TRACE_ANALYZED=1

    utils::log INFO "Analyzing trace file: $TRACE_FILE"

    # =========================================================
    # CAPTURE ALL FAILURES
    # =========================================================
    mapfile -t failed_lines < <(
        grep -E "=[[:space:]]*-1[[:space:]]+[A-Z0-9_]+" "$TRACE_FILE" \
        | grep -v "EINVAL"
    )

    utils::log INFO "Failed syscall count: ${#failed_lines[@]}"

    if (( ${#failed_lines[@]} == 0 )); then
        utils::log INFO "No syscall errors detected"
        TRACE_ANALYZED=1
        return 0
    fi

    # =========================================================
    # STRUCTURED PARSING
    # syscall | errno | path
    # =========================================================
    mapfile -t failed_structured < <(
        printf '%s\n' "${failed_lines[@]}" | awk '
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

            key = syscall SUBSEP err SUBSEP path

            if (!(key in seen)) {
                seen[key] = 1
                print syscall "\t" err "\t" path
            }
        }'
    )

    while IFS=$'\t' read -r syscall err path; do
        [[ -z "$syscall" || -z "$err" ]] && continue

        if [[ -n "$path" ]]; then
            utils::log WARN "$syscall failed: $err -> $path"
        else
            utils::log WARN "$syscall failed: $err"
        fi
    done <<< "$(printf '%s\n' "${failed_structured[@]}")"

    # =========================================================
    # SUMMARY
    # =========================================================
    utils::log INFO "Total syscall failures: ${#failed_lines[@]}"
}

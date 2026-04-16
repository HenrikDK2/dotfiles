#!/bin/bash

utils::log() {
    local level="$1"
    shift
    local message="$*"

    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local script_name="$(basename "$CMD")-$$"
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

Examples:
    $(basename "$0") run /usr/bin/firefox
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

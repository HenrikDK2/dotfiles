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
Usage: $(basename "$0") <command> [options]

Commands:
    run <profile> <program> [args...]    Run a program in a sandboxed environment
    generate [profile]                   Generate symlinks for sandboxed applications
    list                                 List available profiles
    help                                 Show this help message

Examples:
    $(basename "$0") run /usr/bin/firefox
    $(basename "$0") generate firefox
    $(basename "$0") generate            # Generate for all profiles
EOF
    exit "${1:-0}"
}

utils::dump_vars() {
	utils::log ERROR "Program exited unexpectedly"
	utils::log INFO "Dumping relevant environment variables:"

    local v
    for v in "${!BASH_VERSINFO[@]}" "${!FUNCNAME[@]}"; do
        :
    done 2>/dev/null

    for v in $(compgen -v); do
        # skip exported variables
        [[ -n "${!v+x}" ]] || continue

        case "$(declare -p "$v" 2>/dev/null)" in
            declare\ -x*) continue ;;
        esac

        printf "%s=%q\n" "$v" "${!v}"
    done
}

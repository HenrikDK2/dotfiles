#!/bin/bash

log() {
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



load_json_no_comments() {
    local input_file="$1"
    local tmp_file="$(mktemp)"

    # remove full-line // comments
    sed '/^\s*\/\//d' "$input_file" > "$tmp_file"

    # return path to cleaned file
    echo "$tmp_file"
}

get_profile_from_cmd() {
    local cmd_name="$1"
    shopt -s nullglob

    for file in "$PROFILES_DIR"/*.json; do
        [[ -f "$file" ]] || continue

        if [[ "$(basename "$file" .json)" == "$cmd_name" ]]; then
        	echo "$(load_json_no_comments "$file")"
            return 0
        fi
    done

    return 1
}

get_array() {
    local section="$1"
    local key="$2"

    jq -r ".${section}.${key}[]?" "$CONFIG_FILE" |
    while IFS= read -r path; do

        if [[ -z "$path" ]]; then
            log ERROR "Empty path in ${section}.${key}" >&2
            return 1
        fi

        path="${path/#\~/$HOME}"
        path="${path/\$HOME/$HOME}"

        printf '%s\n' "$path"
    done
}

get_value() {
    local path="$1"
    jq -r "$path" "$PROFILE_FILE"
}

get_bool() {
    local section="$1"
    local key="$2"
    local val=$(jq -r ".$section.$key" "$PROFILE_FILE")

    if [[ "$val" == "null" || -z "$val" ]]; then
        log ERROR "$key value is empty in $section"
        exit 1
    fi

    echo "$val"
}

check_dependencies() {
    local missing=0
    for pkg in passt jq bwrap xdg-dbus-proxy; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            log ERROR "$pkg not installed"
            missing=1
        fi
    done
    return $missing
}

show_usage() {
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

list_profiles() {
    log INFO "Available profiles:"
    for profile in "$PROFILES_DIR"/*.json; do
        [[ -f "$profile" ]] || continue
        local name=$(basename "$profile" .json)
        echo "  - $name"
    done
    exit 0
}

generate_symlinks() {
    local profile="$1"

    if [[ -n "$profile" ]]; then
        generate_for_profile "$profile"
    else
        # Generate for all profiles
        for profile_file in "$PROFILES_DIR"/*.json; do
            [[ -f "$profile_file" ]] || continue
            local profile_name=$(basename "$profile_file" .json)
            generate_for_profile "$profile_name"
        done
    fi
}

generate_for_profile() {
    local profile="$1"
    local profile_file

    profile_file="$(get_profile_from_cmd "$profile")"

    if [[ ! -f "$profile_file" ]]; then
        log ERROR "Profile not found: $profile"
        return 1
    fi

    log INFO "Generating wrappers for profile: $profile"

    local program=$(jq -r '.executable' "$profile_file")

    if [[ -z "$program" || "$program" == "null" ]]; then
        log WARN "No executable defined in profile: $profile"
        return 0
    fi

    mkdir -p "$SYMLINK_DIR"

    local program_name="$(basename "$program")"
    local target_file="$SYMLINK_DIR/$program_name"

cat > "$SYMLINK_DIR/$program_name" <<EOF
bwrapjail run "/usr/bin/$program_name"
EOF

    chmod +x "$target_file"
}

detect_profile_from_name() {
    local program_name="$(basename "$0")"

    # If called directly as bwrapjail, no auto-detection
    if [[ "$program_name" == "bwrapjail" || "$program_name" == "bwrapjail.sh" ]]; then
        return 1
    fi

    # Search for profile that includes this program
    for profile_file in "$PROFILES_DIR"/*.json; do
        [[ -f "$profile_file" ]] || continue

        if jq -e --arg prog "$program_name" '.executable | select(. == $prog)' "$profile_file" >/dev/null 2>&1; then
            basename "$profile_file" .json
            return 0
        fi
    done

    return 1
}

add_bwrap_arg() {
    BWRAP_ARGS+=( "$@" )
}

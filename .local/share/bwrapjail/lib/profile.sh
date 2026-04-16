profile::validate() {
    PROFILE_FILE="$(profile::get_file "$CMD_NAME" "$CMD_PATH")"

    if [[ -z "$PROFILE_FILE" || ! -f "$PROFILE_FILE" ]]; then
        utils::log ERROR "No profile matches command: $CMD_NAME ($CMD_PATH)"
        exit 1
    fi

    utils::log INFO "Using profile: $CMD_NAME"
}

profile::load_config() {
    PROFILE_JSON="$(<"$PROFILE_FILE")"

    read -r EXECUTABLE \
            ALLOW_NETWORK \
            ALLOW_AUDIO \
            ISOLATE_NAMESPACES \
            ALLOW_GPU \
            ALLOW_WAYLAND \
            ALLOW_X11 \
            ALLOW_DBUS \
            ALLOW_OPEN_URI \
            ALLOW_FILE_CHOOSER \
            ALLOW_PRINT \
            ALLOW_NOTIFICATIONS \
            ALLOW_SCREENSHARE \
            ALLOW_CLIPBOARD \
    <<< "$(jq -r '
      [
        (.executable // ""),
        (.allow_network // false),
        (.allow_audio // false),
        (.isolate_namespaces // false),

        (.graphics.allow_gpu // false),
        (.graphics.allow_wayland // false),
        (.graphics.allow_x11 // false),

        (.dbus != null),
        (.dbus.open_uri // false),
        (.dbus.file_chooser // false),
        (.dbus.print // false),
        (.dbus.notifications // false),
        (.dbus.screenshare // false),
        (.dbus.clipboard // false)
      ]
      | map(tostring)
      | @tsv
    ' "$PROFILE_FILE")"
}

profile::get_file() {
    local cmd_name="$1"

    for file in "$PROFILES_DIR"/*.json; do
        [[ -f "$file" ]] || continue
        if [[ "$(basename "$file" .json)" == "$cmd_name" ]]; then
            local tmp_file="$(mktemp)"
            sed '/^\s*\/\//d' "$file" > "$tmp_file"
            echo "$tmp_file"
        fi
    done
}

profile::list() {
    utils::log INFO "Available profiles:"
    for profile in "$PROFILES_DIR"/*.json; do
        [[ -f "$profile" ]] || continue
        local name=$(basename "$profile" .json)
        echo "  - $name"
    done
    exit 0
}

profile::generate() {
    local profile="$1"

	gen() {
		local name=$(basename "$1")
	    local file="$PROFILES_DIR/$name.json"
	    local target="$SYMLINK_DIR/$name"

	    # Check if profile exists
	    if [[ ! -f "$file" ]]; then
	        utils::log ERROR "Profile not found: $file"
	        exit 1
	    fi

	    mkdir -p "$SYMLINK_DIR"

	    utils::log INFO "Generating symlink for $name"

	    printf 'bwrapjail run "/usr/bin/%s"\n' "$name" > "$target"
	    chmod +x "$target"
	}

    if [[ -z "$profile" ]]; then
        for file in "$PROFILES_DIR"/*.json; do
            [[ -e "$file" ]] || continue
            gen "$(basename "$file" .json)"
        done
    else
        gen "$profile"
    fi
}

profile::detect_from_name() {
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

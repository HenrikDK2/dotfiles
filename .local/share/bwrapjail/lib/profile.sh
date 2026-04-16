profile::validate() {
    PROFILE_FILE=""
    local executable_name="$(basename "$EXECUTABLE")"

    for file in "$PROFILES_DIR"/*.json; do
        [[ -f "$file" ]] || continue
        if [[ "$(basename "$file" .json)" == "$executable_name" ]]; then
            local tmp_file="$(mktemp)"
            sed '/^\s*\/\//d' "$file" > "$tmp_file"
            PROFILE_FILE="$tmp_file"
            break
        fi
    done

    if [[ -z "$PROFILE_FILE" || ! -f "$PROFILE_FILE" ]]; then
        utils::log ERROR "No profile matches command: $EXECUTABLE"
        exit 1
    fi
    utils::log INFO "Using profile: $(basename "$EXECUTABLE")"
}

profile::load_config() {
    PROFILE_JSON="$(<"$PROFILE_FILE")"

    # Read extra_args into an array
    mapfile -t EXTRA_ARGS < <(jq -r '.cmd.extra_args[]? // empty' "$PROFILE_FILE")

    read -r EXECUTABLE \
            ALLOW_NETWORK \
            ALLOW_AUDIO \
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
        (.cmd.executable // ""),
        (.allow_network // false),
        (.allow_audio // false),
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
      | @tsv
    ' "$PROFILE_FILE")"
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
	    local target="$SYMLINK_DIR/$name"
	    local file="$PROFILES_DIR/$name.json"

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

	echo -e ""
}

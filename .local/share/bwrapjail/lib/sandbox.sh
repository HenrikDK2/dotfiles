sandbox::add_bwrap_arg() {
    local flag="$1"
    local src_pattern="$2"
    local dest_pattern="${3:-$2}"

    _add_one() {
        local src="$1"
        local dest=""

        # ONLY wildcard substitution if explicitly present in dest
        if [[ "$dest_pattern" == *"*"* ]]; then
        	local name="${src##*/}"
        	local prefix="${dest_pattern%\*}"

        	dest="${prefix%/}/${name}"
        else
            # STRICT: no transformation whatsoever
            dest="$dest_pattern"
        fi

        BWRAP_ARGS+=( "$flag" "$src" "$dest" )
    }

    # Case 1: glob expansion (src only)
    if [[ "$src_pattern" == *"*"* ]]; then
        shopt -s nullglob

        for src in $src_pattern; do
            _add_one "$src"
        done

        shopt -u nullglob

    # Case 2: single path
    else
        _add_one "$src_pattern"
    fi
}

sandbox::init_bwrap_base_args() {
	utils::log INFO "Setting up sandbox"

    BWRAP_ARGS=(
        bwrap
        --clearenv
        --new-session
        --hostname mypc

        --proc /proc

        --dev /dev

        --tmpfs /run
        --tmpfs /tmp
    )

    # Make terminal useable in sandbox
    sandbox::add_bwrap_arg --setenv TERM "$TERM"
    sandbox::add_bwrap_arg --setenv PS1 '\u@\h:\w\$ '
}

sandbox::configure_paths(){
	utils::log INFO "Loading sandbox paths"

	while IFS= read -r entry; do
	    [[ -z "$entry" ]] && continue

	    mode=${entry%%:*}
	    path=${entry#*:}

	    path=${path/#\~/$HOME}
	    path=${path//\$HOME/$HOME}

	    case $path in
	        /dev*|/proc*)
	            utils::log WARN "Skipping managed mount: $path"
	            continue
	            ;;
	    esac

	    case $mode in
	        ro)
	            utils::log INFO "Adding read-only bind: $path"
	            sandbox::add_bwrap_arg --ro-bind-try "$path" "$path"
	            ;;
	        rw)
	            utils::log INFO "Adding read-write bind: $path"
	            sandbox::add_bwrap_arg --bind-try "$path" "$path"
	            ;;
	        tmpfs)
	            utils::log WARN "Hidding path $path"
	            sandbox::add_bwrap_arg --tmpfs "$path"
	            ;;
	        *)
	            utils::log ERROR "Invalid mode '$mode' in entry: $entry"
	            exit 1
	            ;;
	    esac
	done < <(jq -r '.paths[]?' <<< "$PROFILE_JSON")
}

sandbox::configure_envs() {
    echo -e ""
    utils::log INFO "Loading environment variables"

    # Read envs from profile JSON
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue

        value=$(jq -r --arg key "$key" '.envs[$key] // empty' <<< "$PROFILE_JSON")

        # Skip if value is empty/null
        [[ -z "$value" || "$value" == "null" ]] && continue

        # Resolve $HOME if needed
        value="${value//\$HOME/$HOME}"

        utils::log INFO "Setting env $key=$value"
        sandbox::add_bwrap_arg --setenv "$key" "$value"

    done < <(jq -r '(.envs // {}) | keys[]' <<< "$PROFILE_JSON")

    echo -e ""
}

sandbox::configure_gpu() {
    if [[ "$ALLOW_GPU" = true ]]; then
        utils::log INFO "Enabling GPU"
        sandbox::add_bwrap_arg --dev-bind-try /dev/nvidia* /dev/nvidia*
        sandbox::add_bwrap_arg --dev-bind-try /dev/kfd /dev/kfd
        sandbox::add_bwrap_arg --ro-bind-try /sys/class/drm /sys/class/drm
        sandbox::add_bwrap_arg --ro-bind-try /sys/devices/pci* /sys/devices/pci*
        sandbox::add_bwrap_arg --dev-bind /sys/dev/char /sys/dev/char
        sandbox::add_bwrap_arg --dev-bind /dev/dri /dev/dri
    fi
}

sandbox::configure_wayland() {
    if [[ "$ALLOW_WAYLAND" = true ]]; then
        utils::log INFO "Enabling Wayland display"
        sandbox::add_bwrap_arg --setenv DISPLAY "$DISPLAY"
        sandbox::add_bwrap_arg --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY"
        sandbox::add_bwrap_arg --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR"
        sandbox::add_bwrap_arg --bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    fi
}

sandbox::configure_x11() {
    if [[ "$ALLOW_X11" = true ]]; then
        utils::log INFO "Enabling X11 socket"
        sandbox::add_bwrap_arg --setenv DISPLAY "$DISPLAY"
        sandbox::add_bwrap_arg --bind /tmp/.X11-unix /tmp/.X11-unix
    fi
}

sandbox::configure_audio() {
    if [[ "$ALLOW_AUDIO" = true ]]; then
        utils::log INFO "Enabling PulseAudio & Pipewire"
        sandbox::add_bwrap_arg --bind "$XDG_RUNTIME_DIR/pulse*" "$XDG_RUNTIME_DIR/pulse*"
        sandbox::add_bwrap_arg --bind "$XDG_RUNTIME_DIR/pulse/*" "$XDG_RUNTIME_DIR/pulse/*"
        sandbox::add_bwrap_arg --bind "$XDG_RUNTIME_DIR/pipewire*" "$XDG_RUNTIME_DIR/pipewire*"
    fi
}

sandbox::configure_network() {
    if [[ "$ALLOW_NETWORK" = false ]]; then
        utils::log INFO "Disabling network access"
        BWRAP_ARGS+=( "--unshare-net" )
    else
   		BWRAP_ARGS+=( "--share-net" )
    fi
}

sandbox::finalize_command() {
	if [[ -n "$COMMAND_OVERRIDE" ]]; then
    	EXECUTABLE="$COMMAND_OVERRIDE"
    fi

    BWRAP_ARGS+=( "--unshare-all" )
    sandbox::configure_network
	BWRAP_ARGS+=( -- "$EXECUTABLE" "${ARGS[@]}${EXTRA_ARGS[@]}" )
    utils::log INFO "Command: ${BWRAP_ARGS[*]}"
}

sandbox::execute() {
    trap sandbox::cleanup EXIT INT TERM

    if [[ "$DEBUG_ENABLED" -eq 1 ]]; then
        if ! command -v strace >/dev/null 2>&1; then
            utils::log ERROR "strace is not installed (required for --trace)"
            exit 1
        fi

        local trace_name="$(basename "$EXECUTABLE")"
        TRACE_FILE="$HOME/${trace_name}.trace"
        echo "" > "$TRACE_FILE"

        utils::log INFO "strace enabled -> $TRACE_FILE"
		LD_DEBUG=libs strace -f -tt -s 128 \
		  -e trace=execve,exit_group,kill,openat,access,stat \
		  -o "$TRACE_FILE" \
		  "${BWRAP_ARGS[@]}"
    else
       	utils::log INFO "Launching sandbox PID: $BWRAP_PID"
        "${BWRAP_ARGS[@]}"
    fi

    BWRAP_PID=$!
    wait "$BWRAP_PID"
}

sandbox::cleanup() {
	if [[ -z "$HAS_CLEANUP_RUN" ]]; then
		HAS_CLEANUP_RUN=1
		utils::debug
	    utils::log INFO "Cleaning up"
	    [[ -n "${BWRAP_PID:-}" ]] && kill "$BWRAP_PID" 2>/dev/null || true
	    [[ -n "${DBUS_PROXY_PID:-}" ]] && kill "$DBUS_PROXY_PID" 2>/dev/null || true
	    [[ -n "${PROXY_SOCKET:-}" ]] && rm -f "$PROXY_SOCKET"
	    set +x 2>/dev/null || true
	fi
}

sandbox::add_bwrap_arg() {
    BWRAP_ARGS+=( "$@" )
}

sandbox::init_bwrap_base_args() {
	utils::log INFO "Setting up sandbox"

    BWRAP_ARGS=(
        bwrap
        --clearenv
        --unshare-all
        --share-net

        --proc /proc
        --dev /dev
        --tmpfs /tmp

        --ro-bind /var /var
        --ro-bind /sys /sys
        --ro-bind /usr /usr
        --ro-bind /lib /lib
        --ro-bind /lib64 /lib64
        --ro-bind /opt /opt
        --ro-bind /bin /bin

        --bind /etc /etc
    )
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

sandbox::configure_gpu() {
    if [[ "$ALLOW_GPU" = true ]]; then
        utils::log INFO "Enabling GPU"
        sandbox::add_bwrap_arg --dev-bind-try /dev/nvidia* /dev/nvidia*
        sandbox::add_bwrap_arg --dev-bind-try /dev/kfd /dev/kfd
        sandbox::add_bwrap_arg --ro-bind-try /sys/class/drm /sys/class/drm
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
        utils::log INFO "Enabling PulseAudio"
        sandbox::add_bwrap_arg --bind "$XDG_RUNTIME_DIR/pulse*" "$XDG_RUNTIME_DIR/pulse*"
        sandbox::add_bwrap_arg --bind "$XDG_RUNTIME_DIR/pipewire*" "$XDG_RUNTIME_DIR/pipewire*"
    fi
}

sandbox::configure_network() {
    if [[ "$ALLOW_NETWORK" = false ]]; then
        utils::log INFO "Disabling network access"
        sandbox::add_bwrap_arg --unshare-net
    fi
}

sandbox::finalize_command() {
	if [[ -n "$COMMAND_OVERRIDE" ]]; then
    	CMD=( "$COMMAND_OVERRIDE" )
    fi

	sandbox::add_bwrap_arg -- "${CMD[@]}"

    # capture ldd output
    local ldd_output="$(ldd "$EXECUTABLE" 2>&1)"

    # only log if it's a dynamic executable
    if [[ "$ldd_output" != *"not a dynamic executable"* ]]; then
        utils::log INFO "ldd output for $EXECUTABLE:"
        utils::log INFO "$ldd_output"
    fi

    utils::log INFO "Command: ${BWRAP_ARGS[*]}"
}

sandbox::execute() {
    trap sandbox::cleanup EXIT INT TERM

    "${BWRAP_ARGS[@]}" 2> >(while read -r line; do utils::log ERROR "$line"; done) &
    BWRAP_PID=$!

    utils::log INFO "Launching sandbox PID: $BWRAP_PID"
    wait "$BWRAP_PID"
}

sandbox::cleanup() {
    utils::log INFO "Cleaning up"
    [[ -n "${BWRAP_PID:-}" ]] && kill "$BWRAP_PID" 2>/dev/null || true
    [[ -n "${DBUS_PROXY_PID:-}" ]] && kill "$DBUS_PROXY_PID" 2>/dev/null || true
    [[ -n "${PROXY_SOCKET:-}" ]] && rm -f "$PROXY_SOCKET"
}

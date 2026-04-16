sandbox::add_bwrap_arg() {
    BWRAP_ARGS+=( "$@" )
}

sandbox::init_bwrap_base_args() {
    BWRAP_ARGS=(
        bwrap
        --clearenv
        --unshare-all
        --share-net
        --proc /proc
        --dev /dev
        --tmpfs /tmp

        --bind /var /var
        --bind /run/user/1000 /run/user/1000
        --ro-bind /sys /sys

        --bind /usr /usr
        --bind /opt /opt
        --bind /lib /lib
        --bind /lib64 /lib64
        --bind /bin /bin
        --bind /etc /etc
        --bind /home /home
    )
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
    else
        unset WAYLAND_DISPLAY
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
        sandbox::add_bwrap_arg --bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"
    fi
}

sandbox::configure_network() {
    if [[ "$ALLOW_NETWORK" = false ]]; then
        utils::log INFO "Disabling network access"
        sandbox::add_bwrap_arg --unshare-net
    fi
}

sandbox::finalize_command() {
    sandbox::add_bwrap_arg -- "$EXECUTABLE"
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

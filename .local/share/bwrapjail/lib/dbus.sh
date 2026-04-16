dbus::add_portal() {
    utils::log INFO "Enabling D-Bus portal: $1"
    PROXY_ARGS+=(--talk="$1")
}

dbus::configure_portals() {
    PROXY_ARGS=()
    local -a ENABLED_PORTALS=()

    add_portal_logged() {
        ENABLED_PORTALS+=("$1")
        dbus::add_portal "$1"
    }

    if [[ "$ALLOW_OPEN_URI" = true ]]; then
        sandbox::add_bwrap_arg --bind /usr/bin/xdg-open /usr/bin/xdg-open
        add_portal_logged org.freedesktop.portal.OpenURI
        sandbox::add_bwrap_arg --setenv PATH /usr/bin:/bin:/usr/sbin:/sbin
    fi

    if [[ "$ALLOW_FILE_CHOOSER" = true ]]; then
        add_portal_logged org.freedesktop.portal.FileChooser
    fi

    if [[ "$ALLOW_CLIPBOARD" = true ]]; then
        add_portal_logged org.freedesktop.portal.Clipboard
    fi

    if [[ "$ALLOW_PRINT" = true ]]; then
        add_portal_logged org.freedesktop.portal.Print
    fi

    if [[ "$ALLOW_NOTIFICATIONS" = true ]]; then
        add_portal_logged org.freedesktop.portal.Notification
        add_portal_logged org.freedesktop.portal.Notifications
        add_portal_logged org.freedesktop.Notifications
    fi

    if [[ "$ALLOW_SCREENSHARE" = true ]]; then
        add_portal_logged org.freedesktop.portal.ScreenCast
        sandbox::add_bwrap_arg --setenv XDG_SESSION_TYPE "wayland"
    fi

    if ((${#ENABLED_PORTALS[@]} > 0)); then
        utils::log INFO "D-Bus portals enabled (${#ENABLED_PORTALS[@]}): ${ENABLED_PORTALS[*]}"
    else
        utils::log INFO "No D-Bus portals enabled"
    fi
}

dbus::setup_proxy() {
    if [[ "$ALLOW_DBUS" = true ]]; then
        utils::log INFO "Setting up D-Bus proxy"

        PROXY_SOCKET="$XDG_RUNTIME_DIR/bus-proxy-$(uuidgen).sock"

        local -a proxy_args=()
        dbus::configure_portals proxy_args

        sandbox::add_bwrap_arg --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$PROXY_SOCKET"

        xdg-dbus-proxy \
            "$DBUS_SESSION_BUS_ADDRESS" \
            "$PROXY_SOCKET" \
            "${proxy_args[@]}" &

        DBUS_PROXY_PID=$!
        sandbox::add_bwrap_arg --bind "$XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR"
    else
        utils::log INFO "DBus disabled entirely"
        unset DBUS_SESSION_BUS_ADDRESS
        unset XDG_RUNTIME_DIR
    fi
}

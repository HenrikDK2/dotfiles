#!/usr/bin/env bash

dbus::remove_from_default() {
    local target="$1"
    local new=()

    for p in "${DBUS_PORTALS[@]}"; do
        [[ "$p" == "$target" ]] && continue
        new+=("$p")
    done

    DBUS_PORTALS=("${new[@]}")
}

dbus::configure_portals() {
    if [[ "$ALLOW_OPEN_URI" = false ]]; then
        dbus::remove_from_default org.freedesktop.portal.OpenURI
    else
	    sandbox::add_bwrap_arg --bind /usr/bin/xdg-open /usr/bin/xdg-open
	    sandbox::add_bwrap_arg --setenv PATH /usr/bin:/bin:/usr/sbin:/sbin
	    sandbox::add_bwrap_arg --bind-try /usr/bin/protontricks-launch /usr/bin/protontricks-launch
	    sandbox::add_bwrap_arg --bind-try /usr/bin/protontricks /usr/bin/protontricks
	    sandbox::add_bwrap_arg --bind-try /usr/share/steam/compatibilitytools.d /usr/share/steam/compatibilitytools.d
	    sandbox::add_bwrap_arg --bind-try $HOME/.local/share/Steam $HOME/.local/share/Steam
	    sandbox::add_bwrap_arg --bind-try $HOME/.local/share/applications/nxm-handler.desktop $HOME/.local/share/applications/nxm-handler.desktop
	    sandbox::add_bwrap_arg --bind-try $HOME/.local/share/modorganizer $HOME/.local/share/modorganizer
	    sandbox::add_bwrap_arg --bind-try $HOME/Games $HOME/Games
    fi

    if [[ "$ALLOW_FILE_CHOOSER" = false ]]; then
        dbus::remove_from_default org.freedesktop.portal.FileChooser
    fi

    if [[ "$ALLOW_CLIPBOARD" = false ]]; then
        dbus::remove_from_default org.freedesktop.portal.Clipboard
    fi

    if [[ "$ALLOW_PRINT" = false ]]; then
        dbus::remove_from_default org.freedesktop.portal.Print
    fi

    if [[ "$ALLOW_NOTIFICATIONS" = false ]]; then
        dbus::remove_from_default org.freedesktop.portal.Notification
        sandbox::add_bwrap_arg --ro-bind /dev/null /usr/bin/notify-send
    fi

    if [[ "$ALLOW_SCREENSHARE" = false ]]; then
        dbus::remove_from_default org.freedesktop.portal.ScreenCast
        dbus::remove_from_default org.freedesktop.portal.RemoteDesktop
    else
        sandbox::add_bwrap_arg --setenv XDG_SESSION_TYPE "wayland"
    fi

    sandbox::add_bwrap_arg --bind /run/dbus/system_bus_socket /run/dbus/system_bus_socket

    for portal in "${DBUS_PORTALS[@]}"; do
        PROXY_ARGS+=(--talk="$portal")
    done
}

dbus::setup_proxy() {
    if [[ "$ALLOW_DBUS" != true ]]; then
        utils::log INFO "DBus disabled entirely"
        return 0
    fi

    utils::log INFO "Setting up D-Bus proxy"

    PROXY_SOCKET="$XDG_RUNTIME_DIR/bus-proxy-$(uuidgen).sock"

    if [[ "$DEBUG_ENABLED" == "1" ]]; then
        PROXY_ARGS+=(--log)
    fi

    utils::log INFO "D-Bus proxy args:"
    for arg in "${PROXY_ARGS[@]}"; do
        utils::log INFO "  $arg"
    done

    utils::log INFO "Proxy socket: $PROXY_SOCKET"
    utils::log INFO "Upstream bus: $DBUS_SESSION_BUS_ADDRESS"

    sandbox::add_bwrap_arg \
        --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$PROXY_SOCKET"

    xdg-dbus-proxy \
        "$DBUS_SESSION_BUS_ADDRESS" \
        "$PROXY_SOCKET" \
        "${PROXY_ARGS[@]}" --filter &

    DBUS_PROXY_PID=$!

    sandbox::add_bwrap_arg --bind "$PROXY_SOCKET" "$PROXY_SOCKET"
}

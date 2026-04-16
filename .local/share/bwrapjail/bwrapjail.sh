#!/bin/bash

SYMLINK_DIR="$HOME/.local/bin"
PROFILES_DIR="$HOME/.local/share/bwrapjail/profiles"

source "$HOME/.local/share/bwrapjail/lib/utils.sh"

case "${1:-}" in
    run)
        shift
        if [ $# -lt 1 ]; then
            log ERROR "run requires <program> [args...]"
            show_usage 1
        fi
        CMD=( "$@" )
        CMD_PATH="${CMD[0]}"
        CMD_NAME="$(basename "$CMD_PATH")"
        ;;

    generate)
        shift
        check_dependencies || exit 1
        generate_symlinks "$1"
        exit 0
        ;;

    list)
        list_profiles
        exit 0
        ;;

	*)
	    show_usage 1
	    ;;
esac

# -----------------------------
# PROFILE VALIDATION
# -----------------------------

check_dependencies || exit 1

PROFILE_FILE="$(get_profile_file "$CMD_NAME" "$CMD_PATH")"

if [[ -z "$PROFILE_FILE" || ! -f "$PROFILE_FILE" ]]; then
    log ERROR "No profile matches command: $CMD_NAME ($CMD_PATH)"
    exit 1
fi

log INFO "Using profile: $CMD_NAME"
generate_symlinks "$CMD_NAME"

# -----------------------------
# LOAD PROFILE
# -----------------------------

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

log INFO "----- Loaded Profile Config -----"

log INFO "EXECUTABLE           = $EXECUTABLE"
log INFO "ALLOW_NETWORK        = $ALLOW_NETWORK"
log INFO "ALLOW_AUDIO          = $ALLOW_AUDIO"
log INFO "ISOLATE_NAMESPACES   = $ISOLATE_NAMESPACES"

log INFO "ALLOW_GPU            = $ALLOW_GPU"
log INFO "ALLOW_WAYLAND        = $ALLOW_WAYLAND"
log INFO "ALLOW_X11            = $ALLOW_X11"

log INFO "ALLOW_DBUS           = $ALLOW_DBUS"
log INFO "OPEN_URI             = $ALLOW_OPEN_URI"
log INFO "FILE_CHOOSER         = $ALLOW_FILE_CHOOSER"
log INFO "PRINT                = $ALLOW_PRINT"
log INFO "NOTIFICATIONS        = $ALLOW_NOTIFICATIONS"
log INFO "SCREENSHARE         = $ALLOW_SCREENSHARE"
log INFO "CLIPBOARD           = $ALLOW_CLIPBOARD"

log INFO "--------------------------------"

# -----------------------------
# BUILD BWRAP COMMAND
# -----------------------------

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

# -------------------------------------
# GRAPHICS / DISPLAY / AUDIO / NETWORK
# -------------------------------------

if [[ "$ALLOW_GPU" = true ]]; then
    log INFO "Enabling GPU"
    add_bwrap_arg --dev-bind-try /dev/nvidia* /dev/nvidia*
    add_bwrap_arg --dev-bind-try /dev/kfd /dev/kfd
    add_bwrap_arg --ro-bind-try /sys/class/drm /sys/class/drm
    add_bwrap_arg --dev-bind /dev/dri /dev/dri
fi

if [[ "$ALLOW_WAYLAND" = true ]]; then
    log INFO "Enabling Wayland display"
    add_bwrap_arg --setenv DISPLAY "$DISPLAY"
    add_bwrap_arg --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY"
   	add_bwrap_arg --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR"
    add_bwrap_arg --bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
else
	unset WAYLAND_DISPLAY
fi

if [[ "$ALLOW_X11" = true ]]; then
    log INFO "Enabling X11 socket"
    add_bwrap_arg --setenv DISPLAY "$DISPLAY"
    add_bwrap_arg --bind /tmp/.X11-unix /tmp/.X11-unix
fi

if [[ "$ALLOW_AUDIO" = true ]]; then
    log INFO "Enabling PulseAudio"
    add_bwrap_arg --bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"
fi

if [[ "$ALLOW_NETWORK" = false ]]; then
    log INFO "Disabling network access"
    add_bwrap_arg --unshare-net
fi

# -----------------------------
# DBUS
# -----------------------------

DBUS_PROXY_PID=""

if [[ "$ALLOW_DBUS" = true ]]; then
    log INFO "Setting up D-Bus proxy"

    PROXY_SOCKET="$XDG_RUNTIME_DIR/bus-proxy-$(uuidgen).sock"
    PROXY_ARGS=()

    add_portal() {
        PROXY_ARGS+=(--talk="$1")
    }

	if [[ "$ALLOW_OPEN_URI" = true ]]; then
	    add_bwrap_arg --bind /usr/bin/xdg-open /usr/bin/xdg-open
	    add_portal org.freedesktop.portal.OpenURI
		add_bwrap_arg --setenv PATH /usr/bin:/bin:/usr/sbin:/sbin
	fi

	if [[ "$ALLOW_FILE_CHOOSER" = true ]]; then
	    add_portal org.freedesktop.portal.FileChooser
	fi

	if [[ "$ALLOW_CLIPBOARD" = true ]]; then
	    add_portal org.freedesktop.portal.Clipboard
	fi

	if [[ "$ALLOW_PRINT" = true ]]; then
	    add_portal org.freedesktop.portal.Print
	fi

	if [[ "$ALLOW_NOTIFICATIONS" = true ]]; then
	    add_portal org.freedesktop.portal.Notification
	    add_portal org.freedesktop.portal.Notifications
	    add_portal org.freedesktop.Notifications
	fi

	if [[ "$ALLOW_SCREENSHARE" = true ]]; then
	    add_portal org.freedesktop.portal.ScreenCast
	    add_bwrap_arg --setenv XDG_SESSION_TYPE "wayland"
	fi

	add_bwrap_arg --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$PROXY_SOCKET"

    xdg-dbus-proxy \
        "$DBUS_SESSION_BUS_ADDRESS" \
        "$PROXY_SOCKET" \
        "${PROXY_ARGS[@]}" &

    DBUS_PROXY_PID=$!
    add_bwrap_arg --bind "$XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR"
else
    log INFO "DBus disabled entirely"
    unset DBUS_SESSION_BUS_ADDRESS
    unset XDG_RUNTIME_DIR
fi

# -----------------------------
# RUN
# -----------------------------

add_bwrap_arg -- "$EXECUTABLE"
log INFO "Command: ${BWRAP_ARGS[*]}"
BWRAP_PID=""

cleanup() {
    log INFO "Cleaning up"
    [[ -n "${BWRAP_PID:-}" ]] && kill "$BWRAP_PID" 2>/dev/null || true
    [[ -n "${DBUS_PROXY_PID:-}" ]] && kill "$DBUS_PROXY_PID" 2>/dev/null || true
    [[ -n "${PROXY_SOCKET:-}" ]] && rm -f "$PROXY_SOCKET"
}

trap cleanup EXIT INT TERM
"${BWRAP_ARGS[@]}" 2> >(while read -r line; do log ERROR "$line"; done) &
BWRAP_PID=$!
log INFO "Launching sandbox PID: $BWRAP_PID"

wait "$BWRAP_PID"

#!/bin/bash

SYMLINK_DIR="$HOME/.local/bin"
PROFILES_DIR="$HOME/.local/share/bwrapjail/profiles"

declare -a BWRAP_ARGS=()
declare BWRAP_PID=""

declare DBUS_PROXY_PID=""
declare PROXY_SOCKET=""
declare PROXY_ARGS=()
declare DBUS_PORTALS=(
    org.freedesktop.portal.Desktop
    org.freedesktop.portal.FileChooser
    org.freedesktop.portal.OpenURI
    org.freedesktop.portal.Notification
    org.freedesktop.portal.Clipboard
    org.freedesktop.portal.Print
    org.freedesktop.portal.ScreenCast
    org.freedesktop.portal.RemoteDesktop
    org.freedesktop.portal.Settings
    org.freedesktop.portal.AppChooser
    org.freedesktop.portal.Camera
    org.freedesktop.portal.Location
    org.freedesktop.portal.InputCapture
    org.freedesktop.portal.Secret
    org.freedesktop.portal.Account
    org.freedesktop.portal.Inhibit
    org.freedesktop.portal.DynamicLauncher
    org.freedesktop.portal.GameMode
    org.freedesktop.portal.Realtime
    org.kde.StatusNotifierWatcher
    org.a11y.Bus
    org.mpris.MediaPlayer2.*
    org.gnome.SessionManager
    org.freedesktop.PowerManagement
    org.freedesktop.login1
    org.freedesktop.systemd1
    org.freedesktop.impl.portal.PermissionStore
    org.freedesktop.impl.portal.desktop.gtk
    org.freedesktop.impl.portal.desktop.hyprland
)

declare PROFILE_FILE=""
declare PROFILE_JSON=""

declare EXECUTABLE=""
declare EXTRA_ARGS=""
declare COMMAND_OVERRIDE=""

declare DEBUG_ENABLED=0
declare TRACE_FILE=""

declare ALLOW_NETWORK=""
declare ALLOW_AUDIO=""
declare ALLOW_GPU=""
declare ALLOW_WAYLAND=""
declare ALLOW_X11=""
declare ALLOW_DBUS=""
declare ALLOW_OPEN_URI=""
declare ALLOW_FILE_CHOOSER=""
declare ALLOW_PRINT=""
declare ALLOW_NOTIFICATIONS=""
declare ALLOW_SCREENSHARE=""
declare ALLOW_CLIPBOARD=""

source "$HOME/.local/share/bwrapjail/lib/utils.sh"
source "$HOME/.local/share/bwrapjail/lib/profile.sh"
source "$HOME/.local/share/bwrapjail/lib/sandbox.sh"
source "$HOME/.local/share/bwrapjail/lib/dbus.sh"

trap utils::dump_vars EXIT
utils::check_dependencies || exit 1

case "${1:-}" in
	run)
	    shift
	    [ $# -lt 1 ] && utils::show_usage

		EXECUTABLE="$1"
		shift
		ARGS=()

		while [[ $# -gt 0 ]]; do
		    case "$1" in
		        --command)
		            shift
		            COMMAND_OVERRIDE="$1"
		            ;;
		        --debug)
		            DEBUG_ENABLED=1
		            ;;
		        --)
		            shift
		            ARGS+=( "$@" )
		            break
		            ;;
		        *)
		            ARGS+=( "$1" )
		            ;;
		    esac
		    shift
		done

	    [[ -z "$EXECUTABLE" ]] && utils::show_usage

	    profile::validate
	    profile::generate
	    profile::load_config

	    sandbox::init_bwrap_base_args
		sandbox::configure_profile_paths
		sandbox::configure_envs
	    sandbox::configure_gpu
	    sandbox::configure_wayland
	    sandbox::configure_x11
	    sandbox::configure_audio

	    dbus::configure_portals
	    dbus::setup_proxy

	    sandbox::finalize_command
	    sandbox::execute
	    ;;

    generate)
        shift
        profile::generate
        ;;

    list)
        profile::list_profiles
        ;;

    *)
        utils::show_usage
        ;;
esac

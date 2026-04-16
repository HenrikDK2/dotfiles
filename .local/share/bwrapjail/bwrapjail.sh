#!/bin/bash

SYMLINK_DIR="$HOME/.local/bin"
PROFILES_DIR="$HOME/.local/share/bwrapjail/profiles"

declare -a BWRAP_ARGS=()
declare -a CMD=()
declare CMD_PATH=""
declare CMD_NAME=""
declare DBUS_PROXY_PID=""
declare BWRAP_PID=""
declare PROXY_SOCKET=""
declare PROXY_ARGS=()

declare PROFILE_FILE=""
declare PROFILE_JSON=""

# Profile configuration variables
declare EXECUTABLE=""
declare ALLOW_NETWORK=""
declare ALLOW_AUDIO=""
declare ISOLATE_NAMESPACES=""
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
        if [ $# -lt 1 ]; then
            utils::log ERROR "run requires <program> [args...]"
            utils::show_usage 1
        fi

        CMD=( "$@" )
        CMD_PATH="${CMD[0]}"
        CMD_NAME="$(basename "$CMD_PATH")"

	    profile::validate
  		profile::generate "$CMD_PATH"
		profile::load_config

		sandbox::init_bwrap_base_args
		sandbox::configure_gpu
		sandbox::configure_wayland
		sandbox::configure_x11
		sandbox::configure_audio
		sandbox::configure_network

		dbus::configure_portals
		dbus::setup_proxy

		sandbox::finalize_command
		sandbox::execute
        ;;

    generate)
        shift
        profile::generate "$1"
        ;;

    list)
        profile::list_profiles
        ;;

    *)
        utils::show_usage 1
        ;;
esac

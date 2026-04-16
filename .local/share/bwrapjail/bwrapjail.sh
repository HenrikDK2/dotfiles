#!/bin/bash

SYMLINK_DIR="$HOME/.local/bin"
PROFILES_DIR="$HOME/.local/share/bwrapjail/profiles"

declare -a BWRAP_ARGS=()
declare BWRAP_PID=""

declare DBUS_PROXY_PID=""
declare PROXY_SOCKET=""
declare PROXY_ARGS=()

declare PROFILE_FILE=""
declare PROFILE_JSON=""

declare EXECUTABLE=""
declare EXTRA_ARGS=""

declare TRACE_FILE=""
declare TRACE_ENABLED=0

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

	    COMMAND_OVERRIDE=""
        EXECUTABLE=( $1 )
	    ARGS=()

	    while [[ $# -gt 0 ]]; do
	        case "$1" in
	            --command)
	                shift
	                COMMAND_OVERRIDE="$1"
	                shift
	                ;;
				--trace)
					shift
    				TRACE_ENABLED=1
        			;;
	            *)
	                ARGS+=( "$1" )
	                shift
	                ;;
	        esac
	    done

	    [[ ${#ARGS[@]} -lt 1 ]] && utils::show_usage

	    profile::validate
	    profile::generate
	    profile::load_config

	    sandbox::init_bwrap_base_args
		sandbox::configure_paths
		sandbox::configure_envs
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
        profile::generate
        ;;

    list)
        profile::list_profiles
        ;;

    *)
        utils::show_usage
        ;;
esac

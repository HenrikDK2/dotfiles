#!/bin/bash

add_env() {
	local item
	declare -A seen

	emit() {
		local var="$1"
		local value="$2"

		# Check if variable exists (is set).
		[[ -z "${!var+x}" ]] && return

		if [[ -z "${seen[$var]+x}" ]]; then
			seen["$var"]=1
			printf '%s\n' "__SETENV__:$var:$value"
		fi
	}

	# Preserve incoming pipeline data.
	while IFS= read -r item; do
		printf '%s\n' "$item"

		case "$item" in
			*wayland*)
				emit "WAYLAND_DISPLAY" "\$WAYLAND_DISPLAY"
				emit "DISPLAY" "\$DISPLAY"
				;;

			/tmp/.X11-unix*|/tmp/.X11-unix/*|/tmp/.X11-unix/X*|*x11*)
				emit "DISPLAY" "\$DISPLAY"
				emit "XAUTHORITY" "\$XAUTHORITY"
				;;

			/home/*)
				emit "HOME" "\$HOME"
				;;
		esac
	done
}

add_env

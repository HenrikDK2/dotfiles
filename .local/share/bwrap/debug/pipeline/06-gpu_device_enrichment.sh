#!/bin/bash

gpu_device_enrichment() {
	local item
	local -a out=()
	local gpu_detected=0

	# Disable globbing safely (local -o noglob is not valid in bash)
	set -f

	# Read incoming pipeline data and detect GPU-related access patterns.
	while IFS= read -r item; do
		case "$item" in
		/dev/nvidia* | \
			/dev/kfd* | \
			/dev/dri* | \
			/sys/class/drm* | \
			/sys/dev/char* | \
			/sys/devices/pci* | \
			/sys/bus/pci*)
			gpu_detected=1
			;;
		esac

		out+=("$item")
	done

	# re-enable globbing
	set +f

	# inject full GPU stack if any GPU path was seen
	if [[ "$gpu_detected" -eq 1 ]]; then
		out+=(
			"/dev/nvidia"
			"/dev/kfd"
			"/dev/dri"
			"/sys/class/drm"
			"/sys/dev/char"
			"/sys/devices"
		)
	fi

	printf "%s\n" "${out[@]}"
}

gpu_device_enrichment

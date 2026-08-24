#!/bin/bash

pipewire_enrichment() {
	local item
	local pipewire_detected=0

	set -f

	# Read incoming pipeline data and detect PipeWire-related paths.
	while IFS= read -r item; do
		printf '%s\n' "$item"
		[[ "$item" == *pipewire* ]] && pipewire_detected=1
	done

	set +f

	# Add PipeWire runtime and shared data paths when detected.
	[[ "$pipewire_detected" -eq 1 && -n "$XDG_RUNTIME_DIR" ]] && {
		printf '%s\n' \
			"$XDG_RUNTIME_DIR/pipewire-0" \
			"/usr/share/pipewire"
	}
}

pipewire_enrichment

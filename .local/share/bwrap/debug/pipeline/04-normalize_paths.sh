#!/bin/bash

normalize_paths() {
	local item

	while IFS= read -r item; do
		[[ -z "$item" ]] && continue

		normalize_path "$item"
	done
}

normalize_paths

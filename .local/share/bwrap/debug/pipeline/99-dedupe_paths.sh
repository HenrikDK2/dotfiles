#!/bin/bash

dedupe_paths() {
	local item mode path key
	declare -A seen

	while IFS= read -r item; do
		[[ -z "$item" ]] && continue

		mode="${item%%:*}"
		path="${item#*:}"

		[[ "$path" == "$item" ]] && path="$item"

		key="$path"

		if [[ -z "${seen[$key]+x}" ]]; then
			seen["$key"]=1
			printf '%s\n' "$item"
		fi
	done
}

dedupe_paths

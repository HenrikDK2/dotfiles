#!/bin/bash

isolate_deepest_paths() {
	local item path mode exe base tmp
	declare -A all_paths
	declare -A has_children

	exe="$EXECUTABLE"
	base="${exe##*/}"

	# -----------------------------
	# STEP 1: collect valid paths
	# -----------------------------
	while IFS= read -r item; do
		[[ -z "$item" ]] && continue

		mode="${item%%:*}"
		path="${item#*:}"

		[[ "$path" == "$item" ]] && path="$item"

		[[ -z "$path" ]] && continue
		[[ -e "$path" ]] || continue

		all_paths["$path"]=1
	done

	# ---------------------------------------------------------
	# STEP 2: mark parents WITHOUT dirname (FAST PATH WALK)
	# ---------------------------------------------------------
	for path in "${!all_paths[@]}"; do
		tmp="$path"

		# trim upward manually instead of dirname
		while [[ "$tmp" == */* && "$tmp" != "/" ]]; do
			tmp="${tmp%/*}"
			[[ "$tmp" == "" || "$tmp" == "/" ]] && break
			has_children["$tmp"]=1
		done
	done

	# ---------------------------------------------------------
	# STEP 3: emit deepest nodes
	# ---------------------------------------------------------
	for path in "${!all_paths[@]}"; do

		if [[ -n "${has_children[$path]+x}" ]]; then
			if [[ -d "$path" && "${path##*/}" == "$base" ]]; then
				:
			else
				continue
			fi
		fi

		printf "%s\n" "$path"
	done
}

isolate_deepest_paths

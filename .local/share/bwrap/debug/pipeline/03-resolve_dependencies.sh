#!/bin/bash

resolve_dependencies() {
	local item mode path target lib
	declare -A targets seen

	local -a unique_targets=()

	# ---------------------------------------------------------
	# STEP 1: normalize targets
	# ---------------------------------------------------------
	while IFS= read -r item; do
		mode="${item%%:*}"
		path="${item#*:}"

		printf '%s\n' "$item"

		[[ -e "$path" ]] || continue

		if [[ -L "$path" ]]; then
			target="$(readlink -f "$path" 2>/dev/null || echo "$path")"
		else
			target="$path"
		fi

		if [[ -z "${targets[$target]+x}" ]]; then
			targets["$target"]=1
			unique_targets+=("$target")
		fi
	done

	# ---------------------------------------------------------
	# STEP 2: dependency extraction
	# ---------------------------------------------------------
	for target in "${unique_targets[@]}"; do

		case "$target" in
			/proc/* | /dev/* | /sys/* | /run/* | /tmp/*)
				continue
				;;
		esac

		while read -r _ _ lib _; do
			[[ "$lib" != /* ]] && continue

			[[ -n "${seen[$lib]}" ]] && continue
			seen["$lib"]=1

			printf 'dep:%s\n' "$lib"
		done < <(LC_ALL=C ldd "$target" 2>/dev/null)
	done
}

resolve_dependencies

#!/bin/bash

resolve_dependencies() {
	local item path target
	declare -A targets
	local -a unique_targets=()

	# ---------------------------------------------------------
	# STEP 1: normalize targets (same logic as before)
	# ---------------------------------------------------------
	while IFS= read -r item; do
		printf '%s\n' "$item"
		path="${item#*:}"

		[[ -e "$path" ]] || continue

		if [[ -L "$path" ]]; then
			target="$(readlink -f -- "$path" 2>/dev/null)" || target="$path"
		else
			target="$path"
		fi

		case "$target" in
			/proc/*|/dev/*|/sys/*|/run/*|/tmp/*)
				continue
				;;
		esac

		if [[ -z "${targets[$target]+x}" ]]; then
			targets["$target"]=1
			unique_targets+=("$target")
		fi
	done

	(( ${#unique_targets[@]} == 0 )) && return 0

	# ---------------------------------------------------------
	# STEP 2: dependency extraction — run ldd in parallel across
	# cores instead of one fork+subshell per target, then dedupe
	# in a single awk pass instead of a bash `read` loop per line
	# ---------------------------------------------------------
	local -i jobs
	jobs="$(nproc 2>/dev/null || echo 4)"

	printf '%s\0' "${unique_targets[@]}" \
		| xargs -0 -P "$jobs" -n1 ldd 2>/dev/null \
		| awk '$3 ~ /^\// && !seen[$3]++ { print "dep:" $3 }'
}

resolve_dependencies

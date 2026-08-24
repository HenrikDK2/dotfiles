#!/bin/bash

ensure_multilib_roots() {
	local item
	declare -A seen

	while IFS= read -r item; do
		[[ -z "$item" ]] && continue

		if [[ -z "${seen[$item]+x}" ]]; then
			seen["$item"]=1
			printf '%s\n' "$item"
		fi
	done

	[[ -e /lib ]] && printf '%s\n' "/lib"
	[[ -e /lib64 ]] && printf '%s\n' "/lib64"

	[[ -e /usr/lib ]] && printf '%s\n' "/usr/lib"
	[[ -e /usr/lib64 ]] && printf '%s\n' "/usr/lib64"
	[[ -e /usr/lib32 ]] && printf '%s\n' "/usr/lib32"
}

ensure_multilib_roots

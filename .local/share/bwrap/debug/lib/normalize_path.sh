#!/bin/bash

normalize_path() {
	local path="$1"
	local IFS='/'
	local part
	local -a parts stack

	parts=($path)
	stack=()

	for part in "${parts[@]}"; do
		case "$part" in
			'' | '.')
				continue
				;;
			'..')
				((${#stack[@]})) && unset 'stack[-1]'
				;;
			*)
				stack+=("$part")
				;;
		esac
	done

	if ((${#stack[@]} == 0)); then
		printf '/\n'
	else
		printf '/%s' "${stack[*]}" | tr ' ' '/'
		printf '\n'
	fi
}

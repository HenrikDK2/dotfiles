#!/bin/bash

add_executable_context_paths() {
	local base exe home="$HOME"

	if [[ -z "$EXECUTABLE" ]]; then
		# No executable context: preserve incoming pipeline data.
		cat
		return
	fi

	base="${EXECUTABLE##*/}"
	if [[ -z "$base" || "$base" == "/" || "$base" == "." ]]; then
		# Invalid executable: preserve incoming pipeline data.
		cat
		return
	fi

	exe="$base"

	# Preserve incoming pipeline data before adding executable context paths.
	cat

	add_if_exists() {
		local target="$1"
		local dir file match

		[[ -z "$target" ]] && return

		if [[ -e "$target" ]]; then
			printf "%s\n" "$target"
			return
		fi

		dir="$(dirname "$target")"
		file="$(basename "$target")"

		if [[ -d "$dir" ]]; then
			match="$(find "$dir" -maxdepth 1 -iname "$file" -print -quit 2>/dev/null)"
			[[ -n "$match" ]] && printf "%s\n" "$match"
		fi
	}

	add_if_exists "/usr/bin/$exe"
	add_if_exists "/bin/$exe"
	add_if_exists "/usr/local/bin/$exe"
	add_if_exists "/opt/$exe"
	add_if_exists "/usr/share/$exe"
	add_if_exists "/usr/share/doc/$exe"
	add_if_exists "/usr/lib/$exe"
	add_if_exists "/usr/lib64/$exe"
	add_if_exists "$home/.config/$exe"
	add_if_exists "$home/.cache/$exe"
	add_if_exists "$home/.local/share/$exe"
}

add_executable_context_paths

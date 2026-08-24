#!/bin/bash

filter_existing_paths() {
	local item mode path clean_path tmp_name
	local -A seen

	while IFS= read -r item; do
		[[ -z "$item" ]] && continue

		mode="${item%%:*}"
		path="${item#*:}"

		if [[ "$path" == "$item" ]]; then
			clean_path="$item"
		else
			clean_path="$path"
		fi

		# -----------------------
		# FAST REJECTS
		# -----------------------
		[[ -z "$clean_path" ]] && continue

		case "$clean_path" in
			/home | /usr/bin/bwrap | \
			/ | /root* | /newroot* | /oldroot* | \
			/proc* | /dev/core* | /dev/fd* | \
			/dev/console | /dev/full | /dev/null | \
			/dev/nvme* | \
			/dev/pts* | /dev/ptmx | /dev/random | \
			/dev/stdin | /dev/stdout | /dev/stderr | \
			/dev/tty | \
			/dev/udmabuf | /dev/urandom | /dev/zero | \
			/run/dbus/system_bus_socket | \
			/run/user/1000/bus-proxy*)
				continue
				;;
		esac

		# -----------------------
		# IGNORE GENERATED /tmp FILES
		#
		# Matches:
		#   /tmp/pl5b625c9483dc
		#   /tmp/pl5b625c9483dc-lockfile
		#
		# Does NOT match:
		#   /tmp/.X11-unix/X0
		#   /tmp/foo
		#   /tmp/foo.txt
		# -----------------------
		case "$clean_path" in
			/tmp/*)
				tmp_name="${clean_path##*/}"

				if [[ "$tmp_name" =~ ^pl[[:xdigit:]]{12,}(-lockfile)?$ ]]; then
					continue
				fi
				;;
		esac

		# -----------------------
		# DEDUPE
		# -----------------------
		if [[ -n "${seen[$clean_path]+x}" ]]; then
			continue
		fi

		seen["$clean_path"]=1

		# -----------------------
		# FILE EXISTS CHECK
		# -----------------------
		[[ -e "$clean_path" ]] || continue

		printf '%s\n' "$clean_path"
	done
}

filter_existing_paths

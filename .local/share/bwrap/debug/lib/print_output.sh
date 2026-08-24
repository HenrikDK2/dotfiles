#!/bin/bash

copy_to_clipboard() {
	if command -v wl-copy >/dev/null 2>&1; then
		wl-copy
	elif command -v xclip >/dev/null 2>&1; then
		xclip -selection clipboard
	elif command -v xsel >/dev/null 2>&1; then
		xsel --clipboard --input
	elif command -v pbcopy >/dev/null 2>&1; then
		pbcopy
	else
		utils::log WARN "No clipboard tool found (wl-copy/xclip/xsel/pbcopy)"
	fi
}

print_output() {
	local -a input=("$@")

	local -a paths=()
	local -a env_list=()

	local nxm_handler_detected=0
	local i item

	for ((i = 0; i < ${#input[@]}; i++)); do
		item="${input[i]}"
		[[ -z "$item" ]] && continue

		if [[ "$item" == "__ENRICHMENT__:NXM_HANDLER" ]]; then
			nxm_handler_detected=1
			continue
		fi

		# Environment entries are atomic pipeline records:
		# __SETENV__:VARIABLE:VALUE
		if [[ "$item" == __SETENV__:* ]]; then
			env_list+=("${item#__SETENV__:}")
			continue
		fi

		paths+=("$item")
	done

	local -a sorted=()

	if ((${#paths[@]})); then
		mapfile -t sorted < <(
			printf '%s\n' "${paths[@]}" |
				sed 's|^[^:]*:||' |
				sort -u
		)
	fi

	declare -A seen
	local -a rw_list=()
	local -a ro_list=()
	local -a dev_list=()

	local path

	for path in "${sorted[@]}"; do
		[[ -z "$path" ]] && continue
		[[ -n "${seen[$path]+x}" ]] && continue

		seen["$path"]=1

		if [[ "$path" == /dev/* || "$path" == /run* ]]; then
			dev_list+=("$path")
		elif [[ "$path" == /etc/ssl/openssl.cnf ]]; then
			# openssl.cnf is intentionally a regular bind, but remains
			# grouped with the other /etc entries during output.
			rw_list+=("$path")
		elif [[ -e "$path" && -w "$path" ]]; then
			rw_list+=("$path")
		else
			ro_list+=("$path")
		fi
	done

	# Return the grouping key for a path.
	#
	# /lib             -> /lib
	# /lib64           -> /lib
	# /usr/bin/foo     -> /usr/bin
	# /usr/lib/foo     -> /usr/lib
	# /usr/lib32       -> /usr/lib
	# /usr/lib64       -> /usr/lib
	# /usr/share/foo   -> /usr/share
	# /usr/local/foo   -> /usr/local
	# /etc/foo         -> /etc
	# /var/foo         -> /var
	# /tmp/foo         -> /tmp
	get_root() {
		local p="$1"

		case "$p" in
			/lib|/lib/*|/lib64|/lib64/*)
				echo "/lib"
				;;
			/usr/lib|/usr/lib/*|/usr/lib32|/usr/lib32/*|/usr/lib64|/usr/lib64/*)
				echo "/usr/lib"
				;;
			/usr/*)
				echo "$p" | awk -F/ 'NF >= 3 {print "/" $2 "/" $3}'
				;;
			/*)
				echo "$p" | awk -F/ 'NF >= 2 {print "/" $2}'
				;;
			*)
				echo "$p"
				;;
		esac
	}

	print_path() {
		local cmd="$1"
		local p="$2"

		if [[ "$cmd" == "--setenv" ]]; then
			local var val

			IFS=':' read -r var val <<< "$p"

			val="${val//\\$/\$}"

			printf -- "--setenv %s %s\n" "$var" "$val"
			return
		fi

		local out="$p"

		[[ "$p" == "$HOME"* ]] &&
			out="\$HOME${p#$HOME}"

		printf -- "%s %s %s\n" "$cmd" "$out" "$out"
	}

	print_blocks_by_root() {
		local p root prev_root=""

		# Merge all filesystem entries and sort by:
		#   1. grouping root
		#   2. complete path
		while IFS= read -r p; do
			[[ -n "$p" ]] || continue

			root=$(get_root "$p")

			if [[ "$root" != "$prev_root" ]]; then
				[[ -n "$prev_root" ]] && printf '\n'
				prev_root="$root"
			fi

			if [[ "$p" == /dev/* || "$p" == /run* ]]; then
				print_path "--dev-bind-try" "$p"
			elif [[ "$p" == /etc/ssl/openssl.cnf ]]; then
				print_path "--bind-try" "$p"
			elif [[ -e "$p" && -w "$p" ]]; then
				print_path "--bind-try" "$p"
			else
				print_path "--ro-bind-try" "$p"
			fi
		done < <(
			{
				for p in "${rw_list[@]}"; do
					printf '%s\n' "$p"
				done

				for p in "${ro_list[@]}"; do
					printf '%s\n' "$p"
				done

				for p in "${dev_list[@]}"; do
					printf '%s\n' "$p"
				done
			} |
				sed '/^$/d' |
				while IFS= read -r p; do
					printf '%s\t%s\n' "$(get_root "$p")" "$p"
				done |
				sort -k1,1 -k2,2 |
				cut -f2-
		)
	}

	print_blocks_by_root

	echo ""

	# Environment entries are not filesystem paths, so print them
	# directly without going through print_blocks_by_root().
	for item in "${env_list[@]}"; do
		print_path "--setenv" "$item"
	done

	if (( nxm_handler_detected )); then
		echo ""
		echo "# Needed for nxm-handler"

		printf '%s\n' \
			"--bind-try /bin /bin" \
			"--bind-try \$HOME/.local/share/applications/nxm-handler.desktop \$HOME/.local/share/applications/nxm-handler.desktop" \
			"--bind-try \$HOME/.local/share/modorganizer/nxmhandler-launch.sh \$HOME/.local/share/modorganizer/nxmhandler-launch.sh" \
			"--bind-try \$HOME/Games \$HOME/Games" \
			"--bind-try \$HOME/.local/share/Steam/steamapps \$HOME/.local/share/Steam/steamapps" \
			"--bind-try \$HOME/.local/share/Steam/config/config.vdf \$HOME/.local/share/Steam/config/config.vdf" \
			"--bind-try \$HOME/.local/share/Steam/appcache/appinfo.vdf \$HOME/.local/share/Steam/appcache/appinfo.vdf" \
			'--setenv PATH $PATH'
	fi
}

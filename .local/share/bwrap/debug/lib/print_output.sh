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

get_root() {
	local p="${1%/}" a b

	case "$p" in
		/lib|/lib/*|/lib64|/lib64/*)
			echo /lib
			;;
		/usr/lib|/usr/lib/*|/usr/lib32|/usr/lib32/*|/usr/lib64|/usr/lib64/*)
			echo /usr/lib
			;;
		/usr/*)
			p="${p#/}"
			a="${p%%/*}"
			p="${p#*/}"
			b="${p%%/*}"
			echo "/$a/$b"
			;;
		/*)
			p="${p#/}"
			echo "/${p%%/*}"
			;;
		*)
			echo "$p"
			;;
	esac
}

get_sensitive_reason() {
	local p="${1%/}" base="${1##*/}"

	case "$p" in
		/etc/passwd|/etc/group|/etc/hostname)
			echo "Identifiable"
			return
			;;

		/etc/localtime|/etc/hosts)
			echo "Privacy"
			return
			;;

		/etc/shadow|/etc/gshadow|/etc/security/opasswd)
			echo "Security risk"
			return
			;;

		"$HOME"/.ssh|"$HOME"/.ssh/*|"$HOME"/.gnupg|"$HOME"/.gnupg/*|"$HOME"/.aws|"$HOME"/.aws/*|"$HOME"/.azure|"$HOME"/.azure/*|"$HOME"/.config/gcloud|"$HOME"/.config/gcloud/*|"$HOME"/.config/gh|"$HOME"/.config/gh/*|"$HOME"/.kube/config|"$HOME"/.kube/*|"$HOME"/.docker/config.json|"$HOME"/.password-store|"$HOME"/.password-store/*|"$HOME"/.config/keyrings|"$HOME"/.config/keyrings/*|"$HOME"/.netrc|"$HOME"/.authinfo|"$HOME"/.authinfo.gpg)
			echo "Security risk"
			return
			;;
	esac

	case "$base" in
		id_rsa|id_dsa|id_ecdsa|id_ed25519|id_ed25519_sk|id_ecdsa_sk|authorized_keys|authorized_keys2|private.key|private.pem|credentials|credentials.json|credential.json|secret|secrets|secret.json|secrets.json|token|tokens|token.json|tokens.json|password|passwords|password.json|passwords.json|.netrc|.npmrc|.pypirc|*.key|*.p12|*.pfx)
			echo "Security risk"
			return
			;;

		*.pem)
			case "$base" in
				cert.pem|ca.pem|ca-bundle.pem|cacert.pem)
					;;
				*)
					echo "Security risk"
					return
					;;
			esac
			;;
	esac
}

print_path() {
	local cmd="$1" p="$2" out reason var val

	if [[ "$cmd" == --setenv ]]; then
		IFS=: read -r var val <<< "$p"
		val="${val//\\$/\$}"
		printf -- '--setenv %s %s\n' "$var" "$val"
		return
	fi

	out="${p/#"$HOME"/\$HOME}"
	reason=$(get_sensitive_reason "$p")

	if [[ -n "$reason" ]]; then
		printf '# %s %s %s (%s)\n' "$cmd" "$out" "$out" "$reason"
	else
		printf '%s %s %s\n' "$cmd" "$out" "$out"
	fi
}

print_nxm_handler() {
	cat <<'EOF'

# Needed for nxm-handler
--bind-try /bin /bin
--bind-try $HOME/.local/share/applications/nxm-handler.desktop $HOME/.local/share/applications/nxm-handler.desktop
--bind-try $HOME/.local/share/modorganizer/nxmhandler-launch.sh $HOME/.local/share/modorganizer/nxmhandler-launch.sh
--bind-try $HOME/Games $HOME/Games
--bind-try $HOME/.local/share/Steam/steamapps $HOME/.local/share/Steam/steamapps
--bind-try $HOME/.local/share/Steam/config/config.vdf $HOME/.local/share/Steam/config/config.vdf
--bind-try $HOME/.local/share/Steam/appcache/appinfo.vdf $HOME/.local/share/Steam/appcache/appinfo.vdf
--setenv PATH $PATH
EOF
}

print_output() {
	local item path root cmd prev_root=""
	local nxm_handler_detected=0
	local -a paths=() env_list=()
	local -A seen=()

	for item in "$@"; do
		[[ -z "$item" ]] && continue

		case "$item" in
			__ENRICHMENT__:NXM_HANDLER)
				nxm_handler_detected=1
				;;

			__SETENV__:*)
				env_list+=("${item#__SETENV__:}")
				;;

			*)
				paths+=("$item")
				;;
		esac
	done

	while IFS= read -r path; do
		[[ -z "$path" || -n "${seen[$path]+x}" ]] && continue
		seen["$path"]=1

		case "$path" in
			/dev/*|/run*)
				cmd=--dev-bind-try
				;;

			/etc/ssl/openssl.cnf)
				cmd=--bind-try
				;;

			*)
				if [[ -e "$path" && -w "$path" ]]; then
					cmd=--bind-try
				else
					cmd=--ro-bind-try
				fi
				;;
		esac

		root=$(get_root "$path")

		if [[ "$root" != "$prev_root" ]]; then
			[[ -n "$prev_root" ]] && printf '\n'
			prev_root="$root"
		fi

		print_path "$cmd" "$path"
	done < <(
		printf '%s\n' "${paths[@]}" |
			sed 's|^[^:]*:||' |
			sed '/^$/d' |
			sort -u |
			while IFS= read -r path; do
				printf '%s\t%s\n' "$(get_root "$path")" "$path"
			done |
			sort -k1,1 -k2,2 |
			cut -f2-
	)

	printf '\n'

	for item in "${env_list[@]}"; do
		print_path --setenv "$item"
	done

	(( nxm_handler_detected )) && print_nxm_handler
}

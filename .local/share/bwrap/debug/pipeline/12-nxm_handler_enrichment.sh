#!/bin/bash

nxm_handler_enrichment() {
	local item path
	local nxm_handler_detected=0

	local nxm_script="$HOME/.local/share/modorganizer/nxmhandler-launch.sh"
	local nxm_desktop="$HOME/.local/share/applications/nxm-handler.desktop"

	local -a input=()
	local -a out=()

	set -f

	mapfile -t input

	# =====================================================
	# 1. Detect nxm-handler
	# =====================================================
	for item in "${input[@]}"; do
		path="${item#*:}"
		[[ "$path" == "$item" ]] && path="$item"

		case "$path" in
			"$nxm_script"|"$nxm_desktop")
				nxm_handler_detected=1
				break
				;;
		esac
	done

	# =====================================================
	# 2. Nothing detected → preserve pipeline unchanged
	# =====================================================
	if (( ! nxm_handler_detected )); then
		printf '%s\n' "${input[@]}"
		set +f
		return
	fi

	# =====================================================
	# 3. Remove paths supplied by the nxm-handler block
	# =====================================================
	for item in "${input[@]}"; do
		path="${item#*:}"
		[[ "$path" == "$item" ]] && path="$item"

		case "$path" in
			"$nxm_desktop"|\
			"$nxm_script"|\
			"$HOME/Games"|\
			"$HOME/.local/share/Steam/steamapps"|\
			"$HOME/.local/share/Steam/config/config.vdf"|\
			"$HOME/.local/share/Steam/appcache/appinfo.vdf")
				continue
				;;
		esac

		out+=("$item")
	done

	# =====================================================
	# 4. Emit cleaned pipeline + enrichment record
	# =====================================================
	printf '%s\n' "${out[@]}"
	printf '%s\n' "__ENRICHMENT__:NXM_HANDLER"

	set +f
}

nxm_handler_enrichment

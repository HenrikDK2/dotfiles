#!/bin/bash

collapse_filesystem_roots() {
	declare -A seen
	local item path cut_path exe base prefix key

	exe="$EXECUTABLE"
	base="${exe##*/}"

	while IFS= read -r item; do
		[[ -z $item ]] && continue

		path="${item#*:}"
		[[ $path == "$item" ]] && path=$item
		[[ -z $path || ! -e $path ]] && continue

		cut_path="$(normalize_path "$path")"

		# ALWAYS strip trailing slash for stable keys.
		cut_path="${cut_path%/}"

		# executable collapse
		if [[ $cut_path == */"$base"/* ]]; then
			prefix="${cut_path%%$base*}"
			prefix="${prefix%/}"
			cut_path="${prefix}/${base}"
		fi

		case "$cut_path" in
		# System libraries
		/lib/*) cut_path="/lib" ;;
		/lib64/*) cut_path="/lib64" ;;
		/lib32/*) cut_path="/lib32" ;;
		/usr/lib/*) cut_path="/usr/lib" ;;
		/usr/lib64/*) cut_path="/usr/lib64" ;;
		/usr/lib32/*) cut_path="/usr/lib32" ;;

		# TLS / certificates
		/etc/gnutls/*) cut_path="/etc/gnutls" ;;
		/etc/ca-certificates/*) cut_path="/etc/ca-certificates" ;;
		/usr/share/ca-certificates/*) cut_path="/usr/share/ca-certificates" ;;

		# Locale / time / system data
		/usr/share/locale/*) cut_path="/usr/share/locale" ;;
		/usr/share/X11/locale/*) cut_path="/usr/share/X11/locale" ;;
		/usr/share/zoneinfo/*) cut_path="/usr/share/zoneinfo" ;;

		# Fonts & fontconfig
		/etc/fonts/* | /etc/fonts/conf.d/*) cut_path="/etc/fonts" ;;
		/usr/share/fonts/*) cut_path="/usr/share/fonts" ;;
		/usr/local/share/fonts/*) cut_path="/usr/local/share/fonts" ;;
		/usr/share/fontconfig/*) cut_path="/usr/share/fontconfig" ;;
		/var/cache/fontconfig/*) cut_path="/var/cache/fontconfig" ;;
		"$HOME/.cache/fontconfig"/*) cut_path="$HOME/.cache/fontconfig" ;;
		"$HOME/.fonts"/*) cut_path="$HOME/.fonts" ;;

		# Themes / UI / GTK / icons / misc
		/usr/share/xkeyboard-config-2/*) cut_path="/usr/share/xkeyboard-config-2" ;;
		/usr/share/themes/Default/gtk-3.0/*) cut_path="/usr/share/themes/Default/gtk-3.0" ;;
		"$HOME/.themes"/*) cut_path="$HOME/.themes" ;;

		/usr/share/icons/*) cut_path="/usr/share/icons" ;;
		/usr/share/pixmaps/*) cut_path="/usr/share/pixmaps" ;;
		/usr/share/gtk-3.0/*) cut_path="/usr/share/gtk-3.0" ;;
		"$HOME/.icons"/*) cut_path="$HOME/.icons" ;;
		"$HOME/.config/gtk-3.0"/*) cut_path="$HOME/.config/gtk-3.0" ;;
		"$HOME/.local/share/icons"/*) cut_path="$HOME/.local/share/icons" ;;
		"$HOME/.local/share/gvfs-metadata"/*) cut_path="$HOME/.local/share/gvfs-metadata" ;;
		/usr/share/alsa/*) cut_path="/usr/share/alsa" ;;

		# Graphics stack (Vulkan / Mesa / DRM)
		/usr/share/vulkan/*) cut_path="/usr/share/vulkan" ;;
		"$HOME/.local/share/vulkan"/*) cut_path="$HOME/.local/share/vulkan" ;;
		/usr/share/libdrm/*) cut_path="/usr/share/libdrm" ;;
		/usr/share/drirc.d/*) cut_path="/usr/share/drirc.d" ;;
		/usr/share/glvnd/*) cut_path="/usr/share/glvnd" ;;

		# Caches
		"$HOME/.cache"/*) cut_path="$HOME/.cache" ;;
		/var/cache/mesa_shader_cache/*) cut_path="/var/cache/mesa_shader_cache" ;;

		# MIME / GLib
		/usr/share/mime/*) cut_path="/usr/share/mime" ;;
		"$HOME/.local/share/mime"/*) cut_path="$HOME/.local/share/mime" ;;
		/usr/share/glib-2.0/*) cut_path="/usr/share/glib-2.0" ;;

		# Applications
		$HOME/.local/share/Steam/*) cut_path="$HOME/.local/share/Steam" ;;
		$HOME/.steam/*) cut_path="$HOME/.steam" ;;
		/usr/share/steam/compatibilitytools.d*) cut_path="/usr/share/steam/compatibilitytools.d" ;;

		# /sys & /dev calls
		/sys/devices*) cut_path="/sys/devices" ;;
		/dev/dri/*) cut_path="/sys/dri" ;;

		# Security / credentials
		"$HOME/.ssh"/*) cut_path="$HOME/.ssh" ;;
		"$HOME/.gnupg"/*) cut_path="$HOME/.gnupg" ;;
		"$HOME/.pki/nssdb"/*) cut_path="$HOME/.pki/nssdb" ;;
		esac

		[[ -z $cut_path || $cut_path == "/" ]] && continue

		# Final stable key (this is what fixes duplicates).
		key="$cut_path"

		if [[ -z ${seen[$key]+x} ]]; then
			seen["$key"]=1
			printf '%s\n' "$cut_path"
		fi
	done
}

collapse_filesystem_roots

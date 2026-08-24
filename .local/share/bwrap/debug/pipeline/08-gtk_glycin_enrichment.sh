#!/bin/bash

gtk_glycin_enrichment() {
	local item
	local gtk_detected=0
	local glycin_needed=0

	set -f

	while IFS= read -r item; do
		printf '%s\n' "$item"

		# Detect GTK usage patterns.
		case "$item" in
			*/gtk*|*/libgtk*|*/gdk*|*/glib*|*/gio*|*/pango*|*/cairo*)
				gtk_detected=1
				;;
		esac

		# Direct glycin access already implies need.
		case "$item" in
			*/glycin*)
				glycin_needed=1
				;;
		esac
	done

	set +f

	# Only inject if GTK is in use and glycin wasn't already detected.
	if [[ "$gtk_detected" -eq 1 && "$glycin_needed" -eq 0 ]]; then

		utils::log INFO "GTK detected → adding glycin loader resources"

		# Core glycin loader path.
		[[ -d /usr/share/glycin-loaders ]] &&
			printf '%s\n' "/usr/share/glycin-loaders"

		# Common GTK4 image backend locations (safe fallback).
		[[ -d /usr/lib/gdk-pixbuf-2.0 ]] &&
			printf '%s\n' "/usr/lib/gdk-pixbuf-2.0"

		[[ -d /usr/lib/gio/modules ]] &&
			printf '%s\n' "/usr/lib/gio/modules"
	fi
}

gtk_glycin_enrichment

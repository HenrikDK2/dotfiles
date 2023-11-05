#!/bin/bash

# This script is useful for Heroic Games Launcher
# It will automatically install the redists files inside _redist folder

STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/steam"
PROTON_PATH=/usr/share/steam/compatibilitytools.d/proton-ge-custom/proton
GAME_FOLDER="$PWD"

if [ -z "$STEAM_COMPAT_DATA_PATH" ]; then
	STEAM_COMPAT_DATA_PATH=$WINEPREFIX
elif [ -z "$WINEPREFIX" ]; then
	WINEPREFIX=$STEAM_COMPAT_DATA_PATH
fi

REDISTS_HASH_LIST="$WINEPREFIX/.redists"

function install_dlls() {
	cd "$1" || exit 1

	for file in *.exe; do
		local sha256=$(sha256sum "$file" | cut -d ' ' -f 1)

		# If file_hash doesn't exist in the list
		if ! grep -q "$sha256" "$REDISTS_HASH_LIST"; then
			$PROTON_PATH run "$file"
			echo "$sha256" >> "$REDISTS_HASH_LIST"
		fi
	done
}

if [ ! -f "$REDISTS_HASH_LIST" ]; then
	notify-send -u low "Installing DLLs to new prefix"
	install_dlls "$HOME/.my_scripts/_redist"

	# Install redists files inside game folder
	while read redist; do
		install_dlls "$redist"
	done <<< "$(find "$GAME_FOLDER" -type d -iname '_Redist')"
fi

exec "$@" &

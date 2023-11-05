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

function install_dlls() {
	cd "$1" || exit 1

	for file in *.exe; do
		if [ -f "$file" ]; then
		    $PROTON_PATH run "$file"
		fi
	done
}

if [ ! -f "$WINEPREFIX/redist-done" ]; then
	notify-send -u low "Installing DLLs to new prefix"
	install_dlls "$HOME/.my_scripts/_redist"

	# Install redists files inside game folder
	while read redist; do
		install_dlls "$redist"
	done <<< "$(find "$GAME_FOLDER" -type d -iname '_Redist')"

	touch "$WINEPREFIX/redist-done"
fi

exec "$@" &

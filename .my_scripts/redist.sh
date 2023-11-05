#!/bin/bash

# This script is useful for Heroic Games Launcher
# It will automatically install the redists files inside _redist folder

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/steam"
export PROTON_PATH=/usr/share/steam/compatibilitytools.d/proton-ge-custom/proton

if [ -z $STEAM_COMPAT_DATA_PATH ]; then
	export STEAM_COMPAT_DATA_PATH=$WINEPREFIX
elif [ -z $WINEPREFIX ]; then
	export WINEPREFIX=$STEAM_COMPAT_DATA_PATH
fi

if [ ! -f "$WINEPREFIX/redist-done" ]; then
	notify-send -u low "Installing DLLs to new prefix"

	cd "$HOME/.my_scripts/_redist" || exit 1

	for file in *.exe; do
		if [ -f "$file" ]; then
		    $PROTON_PATH run "$file"
		fi
	done

	touch "$WINEPREFIX/redist-done"
fi

exec "$@" &

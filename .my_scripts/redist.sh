#!/bin/bash

# This script is useful for Heroic Games Launcher
# It will automatically install the redists files inside _redist folder

STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/steam"
PROTON_PATH=/usr/share/steam/compatibilitytools.d/proton-ge-custom/proton
GAME_FOLDER=$(echo "$PWD" | sed -E 's/(bin|bin64)$//I')

if [ -z "$STEAM_COMPAT_DATA_PATH" ]; then
	STEAM_COMPAT_DATA_PATH=$WINEPREFIX
elif [ -z "$WINEPREFIX" ]; then
	WINEPREFIX=$STEAM_COMPAT_DATA_PATH
fi

REDISTS_HASH_LIST="$WINEPREFIX/.redists"

function install_dlls() {
    local redist_dir="$1"
    
    if [ -z "$redist_dir" ] || [ ! -d "$redist_dir" ]; then
        echo "Invalid or missing directory: $redist_dir"
        exit 1
    fi

    find "$redist_dir" -type f -name "*.exe" | while read -r file; do
        local sha256=$(sha256sum "$file" | cut -d ' ' -f 1)

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
	echo "GAME_FOLDER: $GAME_FOLDER" >> $HOME/print

	while read redist; do
		if [ -d "$redist" ]; then
	    	install_dlls "$redist"
		fi
	done <<< "$(find "$GAME_FOLDER" -type d \( -iname '_Redist' -o -iname 'Redist' -o -iname 'Redistributable' -o -iname 'Redistributables' \))"

	# Kill all subprocesses from script
	pgrep -P $$ --signal SIGTERM
fi

exec "$@" &

#!/bin/bash

# This script is useful for Heroic Games Launcher
# It will automatically install the redists files inside _redist folder

if [ -z "$STEAM_COMPAT_DATA_PATH" ]; then
	STEAM_COMPAT_DATA_PATH="$WINEPREFIX"
elif [ -z "$WINEPREFIX" ]; then
	WINEPREFIX="$STEAM_COMPAT_DATA_PATH"
fi

STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/steam"
GAME_FOLDER=$(echo "$PWD" | sed -E 's/(bin|bin64)$//I')
REDISTS_HASH_LIST="$WINEPREFIX/.redists"

if [[ "$WINEDLLPATH" == "$HOME/.config/heroic/tools/wine/Wine-GE-Latest"* ]]; then
	WINE_RUN="$HOME/.config/heroic/tools/wine/Wine-GE-Latest/bin/wine"
fi

function install_dlls() {
    local redist_dir="$1"
    
    if [ -z "$redist_dir" ] || [ ! -d "$redist_dir" ]; then
        echo "Invalid or missing directory: $redist_dir"
        exit 1
    fi

    find "$redist_dir" -type f -name "*.exe" | while read -r file; do
        local sha256=$(sha256sum "$file" | cut -d ' ' -f 1)

        if ! grep -q "$sha256" "$REDISTS_HASH_LIST"; then
            $WINE_RUN $file
            echo "$sha256" >> "$REDISTS_HASH_LIST"
        fi
    done
}

if [ ! -z "$WINE_RUN" ]; then
	install_dlls "$HOME/.my_scripts/_redist"

	# Install redists files inside game folder
	while read redist; do
		if [ -d "$redist" ]; then
	    	install_dlls "$redist"
		fi
	done <<< "$(find "$GAME_FOLDER" -type d \( -iname '_Redist' -o -iname 'Redist' -o -iname 'Redistributable' -o -iname 'Redistributables' \))"

	# Kill all subprocesses from script
	pgrep -P $$ --signal SIGTERM
fi

exec "$@" &

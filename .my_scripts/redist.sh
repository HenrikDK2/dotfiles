#!/bin/bash

log() {
    echo "RedistScript: $1"
}

find_game_folder() {
    if [[ "$PWD" =~ /steamapps/common/([^/]+) ]]; then
        echo "/home/henrik/.local/share/Steam/steamapps/common/${BASH_REMATCH[1]}"
        return 0
    fi
    echo "$(echo "$PWD" | sed -E 's/(bin|bin64)$//I')"
}

if [ -z "$STEAM_COMPAT_DATA_PATH" ]; then
    STEAM_COMPAT_DATA_PATH="$WINEPREFIX"
elif [ -z "$WINEPREFIX" ]; then
    WINEPREFIX="$STEAM_COMPAT_DATA_PATH"
fi

STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/steam"
GAME_FOLDER=$(find_game_folder)
REDISTS_HASH_LIST="$WINEPREFIX/.redists"
RESTART_NEEDED=0

log "GAME_FOLDER: $GAME_FOLDER"
log "STEAM_COMPAT_DATA_PATH: $STEAM_COMPAT_DATA_PATH"
log "WINEPREFIX: $WINEPREFIX"

if [ -x "$PROTONPATH/files/bin/wine" ]; then
    WINE_RUN="$PROTONPATH/files/bin/wine"
elif [ -x "$PROTONPATH/dist/bin/wine" ]; then
    WINE_RUN="$PROTONPATH/dist/bin/wine"
elif [[ "$WINEDLLPATH" == "$HOME/.config/heroic/tools/wine/Wine-GE-Latest"* ]]; then
    WINE_RUN="$HOME/.config/heroic/tools/wine/Wine-GE-Latest/bin/wine"
fi

log "Using Wine: $WINE_RUN"

install_dlls() {
    local redist_dir="$1"

    if [ -z "$redist_dir" ] || [ ! -d "$redist_dir" ]; then
        log "Invalid or missing directory: $redist_dir"
        exit 1
    fi

    # Avoid subshell: Use a for loop with find
    while IFS= read -r -d '' file; do
        log "Found file: $file"
        local sha256=$(sha256sum "$file" | cut -d ' ' -f 1)

        if ! grep -q "$sha256" "$REDISTS_HASH_LIST"; then
            log "Running: $file"
            $WINE_RUN "$file" /quiet
            echo "$sha256" >> "$REDISTS_HASH_LIST"
            RESTART_NEEDED=1  # Update global variable
        else
            log "Already installed (hash matched): $file"
        fi
    done < <(find "$redist_dir" -type f -name "*.exe" -print0)
}

if [ ! -z "$WINE_RUN" ]; then
    install_dlls "$HOME/.my_scripts/_redist"

    while read -r redist; do
        log "Found redist folder: $redist"
        if [ -d "$redist" ]; then
            install_dlls "$redist"
        fi
    done <<< "$(find "$GAME_FOLDER" -type d \( -iname '_Redist' -o -iname 'Redist' -o -iname 'Redistributable' -o -iname 'DotNetCore' -o -iname 'Redistributables' \))"

    if [ $RESTART_NEEDED -eq 1 ]; then
        log "New redistributables installed.\nRestart required!"
        notify-send "RedistScript" "New redistributables were installed.\nRestart required!"
        pkill -9 wineserver
        ps aux | awk '/\.exe$/ {print $2}' | xargs kill
        exit 0
    fi
fi

log "Script execution completed."
exec "$@" &

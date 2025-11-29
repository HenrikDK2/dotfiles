#!/bin/bash

log() {
    echo "RedistScript: $1"
}

find_game_folder() {
    if [[ "$PWD" =~ /steamapps/common/([^/]+) ]]; then
        echo "$HOME/.local/share/Steam/steamapps/common/${BASH_REMATCH[1]}"
        return 0
    fi
    echo "$(echo "$PWD" | sed -E 's/(bin|bin64)$//I')"
}

install_dlls() {
    local redist_dir="$1"

    if [ -z "$redist_dir" ] || [ ! -d "$redist_dir" ]; then
        log "Invalid or missing directory: $redist_dir"
        exit 1
    fi

    # Install dotnet45 first
    install_file "$redist_dir/dotnetfx45_full_x86_x64.exe"

    # Install the rest
    while IFS= read -r -d '' file; do
        install_file "$file"
    done < <(find "$redist_dir" -type f \( -name "*.exe" -o -name "*.msi" \) -print0)
}

install_file() {
    local file="$1"
    local sha256=$(sha256sum "$file" | cut -d ' ' -f1)

    if grep -q "$sha256" "$REDISTS_HASH_LIST"; then
        log "Already installed (hash matched): $file"
        return
    fi

    local flags="/quiet"
    [[ "$file" == *dotnet* ]] && flags="/passive /norestart"
    [[ "$file" == *dxsetup* ]] && flags="/silent"

    log "Running: $file"
    if [[ "$file" == *.msi ]]; then
    	$WINE_RUN msiexec /i "$file" $flags
    else
    	$WINE_RUN "$file" $flags
	fi
	
    echo "$sha256" >> "$REDISTS_HASH_LIST"
}

main() {
    if [ -z "$STEAM_COMPAT_DATA_PATH" ]; then
        STEAM_COMPAT_DATA_PATH="$WINEPREFIX"
    elif [ -z "$WINEPREFIX" ]; then
        WINEPREFIX="$STEAM_COMPAT_DATA_PATH"
    fi

    STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/steam"
    GAME_FOLDER=$(find_game_folder)
    REDISTS_HASH_LIST="$WINEPREFIX/.redists"

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

    if [ ! -z "$WINE_RUN" ]; then
        install_dlls "$HOME/.config/heroic/.redist"

        while read -r redist; do
            log "Found redist folder: $redist"
            if [ -d "$redist" ]; then
                install_dlls "$redist"
            fi
        done <<< "$(find "$GAME_FOLDER" -type d \( \
            -iname '_Redist' -o \
            -iname 'Redist' -o \
            -iname 'Redistributable' -o \
            -iname 'DotNetCore' -o \
            -iname 'Redistributables' -o \
            -iname 'DirectX' -o \
            -iname 'vc_redist' -o \
            -iname 'dotnet' -o \
            -iname 'PhysX' -o \
            -iname 'OpenAL' \
        \))"
    fi

    log "Script execution completed."
    exec "$@" &
}

if [ -z "$HEROIC_APP_SOURCE" ]; then
    main "$@"
else
    exec "$@" &
fi

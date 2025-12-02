#!/bin/bash

REDIST_DOWNLOAD_DIR="$HOME/.config/heroic/redists"
REDIST_METADATA_FILE="$REDIST_DOWNLOAD_DIR/.downloaded_files"

REDIST_FILES=(
    "https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/runtime-aspnetcore-9.0.11-windows-x64-installer|aspnetcore-runtime-9.0.11-win-x64.exe"
    "https://download.microsoft.com/download/b/a/4/ba4a7e71-2906-4b2d-a0e1-80cf16844f5f/dotnetfx45_full_x86_x64.exe|dotnetfx45_full_x86_x64.exe"
    "https://download.visualstudio.microsoft.com/download/pr/6f083c7e-bd40-44d4-9e3f-ffba71ec8b09/3951fd5af6098f2c7e8ff5c331a0679c/ndp481-x86-x64-allos-enu.exe|NDP481-x86-x64-AllOS-ENU.exe"
    "https://download.visualstudio.microsoft.com/download/pr/6f02464a-5e9b-486d-a506-c99a17db9a83/8995548DFFFCDE7C49987029C764355612BA6850EE09A7B6F0FDDC85BDC5C280/VC_redist.x64.exe|VC_redist.x64.exe"
    "https://download.visualstudio.microsoft.com/download/pr/6f02464a-5e9b-486d-a506-c99a17db9a83/E7267C1BDF9237C0B4A28CF027C382B97AA909934F84F1C92D3FB9F04173B33E/VC_redist.x86.exe|VC_redist.x86.exe"
)

NOTIFIED_DOWNLOADING=false
NOTIFIED_INSTALLING=false

STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_DATA_PATH:-$WINEPREFIX}"
WINEPREFIX="${WINEPREFIX:-$STEAM_COMPAT_DATA_PATH}"
REDISTS_HASH_LIST="$WINEPREFIX/.redists"

WINE_RUN="wine"  # default fallback
[ -x "$PROTONPATH/files/bin/wine" ] && WINE_RUN="$PROTONPATH/files/bin/wine"
[ -x "$PROTONPATH/dist/bin/wine" ] && WINE_RUN="$PROTONPATH/dist/bin/wine"
[[ "$WINEDLLPATH" == "$HOME/.config/heroic/tools/wine/Wine-GE-Latest"* ]] && WINE_RUN="$HOME/.config/heroic/tools/wine/Wine-GE-Latest/bin/wine"

log() {
    local message="$1"
    local notify="${2:-false}"  # default false
    echo "RedistScript: $message"
    if [[ "$notify" == "true" ]]; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "RedistScript" "$message"
        fi
    fi
}

download_redists() {
    mkdir -p "$REDIST_DOWNLOAD_DIR"

    # Load previous metadata if exists
    declare -A downloaded_urls
    if [ -f "$REDIST_METADATA_FILE" ]; then
        while IFS="|" read -r filename url; do
            downloaded_urls["$filename"]="$url"
        done < "$REDIST_METADATA_FILE"
    fi

    for entry in "${REDIST_FILES[@]}"; do
        IFS="|" read -r url filename <<< "$entry"
        local filepath="$REDIST_DOWNLOAD_DIR/$filename"

        # Notify only once if downloading
        if [ "$NOTIFIED_DOWNLOADING" == "false" ] && { [ ! -f "$filepath" ] || [ "${downloaded_urls[$filename]}" != "$url" ]; }; then
            log "Missing redistributables found, downloading..." true
            NOTIFIED_DOWNLOADING=true
        fi

        if [ -f "$filepath" ] && [ "${downloaded_urls[$filename]}" = "$url" ]; then
            log "Already downloaded and up-to-date: $filename"
        else
            log "Downloading $filename..."
            curl -L "$url" --output "$filepath"
            if [ $? -ne 0 ]; then
                log "Failed to download $filename. Please check your internet connection or URL."
                continue
            fi
            # Update metadata
            downloaded_urls["$filename"]="$url"
        fi
    done

    # Save updated metadata
    > "$REDIST_METADATA_FILE"
    for f in "${!downloaded_urls[@]}"; do
        echo "$f|${downloaded_urls[$f]}" >> "$REDIST_METADATA_FILE"
    done
}

install_file() {
    local file="$1"
    local sha256=$(sha256sum "$file" | cut -d ' ' -f1)

    if grep -q "$sha256" "$REDISTS_HASH_LIST" 2>/dev/null; then
        log "Already installed (hash matched): $file"
        return
    fi

    # Notify user only once that installation is starting
    if [ "$NOTIFIED_INSTALLING" == "false" ]; then
        log "Installing missing redistributables..." true
        NOTIFIED_INSTALLING=true
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

install_dlls() {
    download_redists

    local dotnet45="$REDIST_DOWNLOAD_DIR/dotnetfx45_full_x86_x64.exe"
    if [ -f "$dotnet45" ]; then
        install_file "$dotnet45"
    fi

    # Install all other files in parallel
    while IFS= read -r -d '' file; do
        [[ "$file" == "$dotnet45" ]] && continue
        install_file "$file" &
    done < <(find "$REDIST_DOWNLOAD_DIR" -type f \( -iname "*.exe" -o -iname "*.msi" \) -print0)

    wait  # Wait for all background jobs to finish
}

main() {
    log "WINEPREFIX: $WINEPREFIX"
    log "REDISTS_HASH_LIST: $REDISTS_HASH_LIST"
    log "REDIST_DOWNLOAD_DIR: $REDIST_DOWNLOAD_DIR"
    log "WINE_RUN: $WINE_RUN"

    install_dlls
    [[ "$NOTIFIED_DOWNLOADING" == "true" || "$NOTIFIED_INSTALLING" == "true" ]] && log "Setup done, launching game..." true
    exec "$@" &
}

if [ -z "$HEROIC_APP_SOURCE" ]; then
    main "$@"
else
    exec "$@" &
fi

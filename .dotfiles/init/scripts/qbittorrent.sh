#!/bin/bash

CONFIG_PATHS=(
    "$HOME/.config/qBittorrent"
    "$HOME/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent"
)

# Check if qBittorrent is installed normally
is_qbittorrent_installed() {
    command -v qbittorrent &>/dev/null
}

# Check if qBittorrent Flatpak is installed
is_qbittorrent_flatpak_installed() {
    flatpak list 2>/dev/null | grep -q "org.qbittorrent.qBittorrent"
}

# Iterate through each config path
for CONFIG_PATH in "${CONFIG_PATHS[@]}"; do
    if [ ! -d "$CONFIG_PATH" ]; then
        # Skip if the relevant qBittorrent installation is not present
        if [[ "$CONFIG_PATH" == "$HOME/.config/qBittorrent" && ! $(is_qbittorrent_installed) ]]; then
            echo "Normal qBittorrent not installed, skipping config copy."
            continue
        elif [[ "$CONFIG_PATH" == "$HOME/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent" && ! $(is_qbittorrent_flatpak_installed) ]]; then
            echo "qBittorrent Flatpak not installed, skipping config copy."
            continue
        fi
        
        # Create config directory and copy the config if not found
        mkdir -p "$CONFIG_PATH"
        cp -r "$SCRIPT_DIR/user/qBittorrent/." "$CONFIG_PATH"
        echo "  ✔ Copied qBittorrent config: $SCRIPT_DIR/user/qBittorrent → $CONFIG_PATH"
    else
        echo "  — qBittorrent config already exists, skipping: $CONFIG_PATH"
    fi
done

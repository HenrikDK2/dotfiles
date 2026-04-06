#!/bin/bash
SCRIPT_DIR="$HOME/.config/dotfiles"

CONFIG_PATHS=(
    "$HOME/.config/qBittorrent"
    "$HOME/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent"
)

for CONFIG_PATH in "${CONFIG_PATHS[@]}"; do
    if [ ! -d "$CONFIG_PATH" ]; then
        mkdir -p "$CONFIG_PATH"
        cp -r "$SCRIPT_DIR/user/qBittorrent/." "$CONFIG_PATH"
        echo "  ✔ Copied qBittorrent config: $SCRIPT_DIR/user/qBittorrent → $CONFIG_PATH"
    else
        echo "  — qBittorrent config already exists, skipping: $CONFIG_PATH"
    fi
done

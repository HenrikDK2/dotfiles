#!/bin/bash

CONFIG_FILE="$HOME/.config/discord/settings.json"

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed." >&2
    exit 1
fi

# Add SKIP_HOST_UPDATE if it doesn't exists
if ! grep -q "SKIP_HOST_UPDATE" "$CONFIG_FILE"; then
    jq '. + {"SKIP_HOST_UPDATE": true}' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi


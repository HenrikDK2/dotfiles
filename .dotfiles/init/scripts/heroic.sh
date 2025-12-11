#!/bin/bash

# Possible Heroic config paths
CONFIG_PATHS=(
  "$HOME/.config/heroic/config.json"
  "$HOME/.var/app/com.heroicgameslauncher.hgl/config/heroic/config.json"
)

for CONFIG in "${CONFIG_PATHS[@]}"; do
    [ -f "$CONFIG" ] || continue

    echo "Processing: $CONFIG"

    # Ensure defaultSettings exists
    jq '
      if .defaultSettings == null then
        .defaultSettings = {}
      else
        .
      end
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

    # Ensure enviromentOptions exists
    jq '
      if .defaultSettings.enviromentOptions == null then
        .defaultSettings.enviromentOptions = []
      else
        .
      end
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

    # Add WINEDLLOVERRIDES only if the key does NOT exist
    jq '
      if any(.defaultSettings.enviromentOptions[]?; .key == "WINEDLLOVERRIDES") then
        .
      else
        .defaultSettings.enviromentOptions += [{
          "key": "WINEDLLOVERRIDES",
          "value": "winhttp=n,b"
        }]
      end
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

    echo "Done."
done

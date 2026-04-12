#!/bin/bash

# Possible Heroic installations and their corresponding config paths
declare -A HEROIC_INSTALLS=(
  ["native"]="$HOME/.config/heroic/config.json"
  ["flatpak"]="$HOME/.var/app/com.heroicgameslauncher.hgl/config/heroic/config.json"
)

# Check if native Heroic is installed
is_native_installed() {
    command -v heroic &>/dev/null
}

# Check if Heroic Flatpak is installed
is_flatpak_installed() {
    flatpak list 2>/dev/null | grep -q "com.heroicgameslauncher.hgl"
}

for INSTALL_TYPE in "${!HEROIC_INSTALLS[@]}"; do
    CONFIG="${HEROIC_INSTALLS[$INSTALL_TYPE]}"

    # Skip if this variant is not installed
    if [ "$INSTALL_TYPE" = "native" ] && ! is_native_installed; then
        echo "Native Heroic not installed, skipping."
        continue
    fi

    if [ "$INSTALL_TYPE" = "flatpak" ] && ! is_flatpak_installed; then
        echo "Heroic Flatpak not installed, skipping."
        continue
    fi

    # Grant Flatpak access to ~/Downloads
    if [ "$INSTALL_TYPE" = "flatpak" ]; then
        echo "Granting Flatpak access to ~/Downloads..."
        flatpak override --user \
            --filesystem=home/Downloads \
            --filesystem=xdg-download \
            com.heroicgameslauncher.hgl
        echo "Flatpak filesystem override applied."
    fi

    # Create config (and parent dirs) if it doesn't exist
    if [ ! -f "$CONFIG" ]; then
        echo "Config not found, creating: $CONFIG"
        mkdir -p "$(dirname "$CONFIG")"
        echo '{}' > "$CONFIG"
    fi

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

    # Enable useSteamRuntime
    jq '
      .defaultSettings.useSteamRuntime = true
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

    echo "Done."
done

#!/bin/bash

CONFIG="$HOME/.config/tidal-hifi/config.json"
NEWLY_CREATED=false

# Create config (and parent dirs) if it doesn't exist
if [ ! -f "$CONFIG" ]; then
    echo "Config not found, creating: $CONFIG"
    mkdir -p "$(dirname "$CONFIG")"
    echo '{}' > "$CONFIG"
    NEWLY_CREATED=true
fi

echo "Processing: $CONFIG"

# Add menuBar only if it doesn't already exist
if jq -e 'has("menuBar")' "$CONFIG" >/dev/null 2>&1; then
    echo "menuBar already exists, leaving unchanged."
else
    echo "Adding menuBar=false..."
    jq '.menuBar = false' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
fi

# Add notifications only if it doesn't already exist
if jq -e 'has("notifications")' "$CONFIG" >/dev/null 2>&1; then
    echo "notifications already exists, leaving unchanged."
else
    echo "Adding notifications=false..."
    jq '.notifications = false' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
fi

echo "Done."

#!/bin/bash
# Steam udev rules installer for Arch Linux
# Only updates when files have changed on GitHub

set -e

UDEV_RULES_DIR="/etc/udev/rules.d"
GITHUB_BASE_URL="https://raw.githubusercontent.com/ValveSoftware/steam-devices/master"
HASH_FILE="/var/lib/steam-udev-rules.hash"

echo "Checking for Steam udev rules updates..."

# Download files to temp location
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

curl -fsSL "${GITHUB_BASE_URL}/60-steam-input.rules" -o "${TMP_DIR}/60-steam-input.rules"
curl -fsSL "${GITHUB_BASE_URL}/60-steam-vr.rules" -o "${TMP_DIR}/60-steam-vr.rules"

# Calculate hash of downloaded files
NEW_HASH=$(cat "${TMP_DIR}/60-steam-input.rules" "${TMP_DIR}/60-steam-vr.rules" | sha256sum | awk '{print $1}')

# Read stored hash if it exists
if [[ -f "$HASH_FILE" ]]; then
    OLD_HASH=$(cat "$HASH_FILE")
else
    OLD_HASH=""
fi

# Compare hashes
if [[ "$NEW_HASH" == "$OLD_HASH" ]]; then
    echo "✓ Steam udev rules are already up to date."
    exit 0
fi

echo "Changes detected, updating rules..."

# Install the files
cp "${TMP_DIR}/60-steam-input.rules" "${UDEV_RULES_DIR}/60-steam-input.rules"
cp "${TMP_DIR}/60-steam-vr.rules" "${UDEV_RULES_DIR}/60-steam-vr.rules"

# Set proper permissions
chmod 644 "${UDEV_RULES_DIR}/60-steam-input.rules"
chmod 644 "${UDEV_RULES_DIR}/60-steam-vr.rules"

# Save new hash
echo "$NEW_HASH" > "$HASH_FILE"

# Reload udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

echo ""
echo "✓ Steam udev rules updated successfully!"
echo "You may need to log out and back in for changes to take full effect."

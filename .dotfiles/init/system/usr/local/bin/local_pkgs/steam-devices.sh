#!/bin/bash
# Steam udev rules installer for Arch Linux
# Only updates when new commits are detected on GitHub
set -e

UDEV_RULES_DIR="/etc/udev/rules.d"
GITHUB_REPO="https://github.com/ValveSoftware/steam-devices.git"
STATE_DIR="/var/lib/steam-udev-rules"
COMMIT_FILE="${STATE_DIR}/last-commit"
REPO_DIR="${STATE_DIR}/repo"

echo "Checking for Steam udev rules updates..."

# Create state directory if it doesn't exist
mkdir -p "$STATE_DIR"

# Clone or update repository
if [[ -d "$REPO_DIR" ]]; then
    # Repository exists, fetch latest
    cd "$REPO_DIR"
    git fetch origin master --quiet
else
    # Clone repository
    git clone --depth 1 "$GITHUB_REPO" "$REPO_DIR" --quiet
    cd "$REPO_DIR"
fi

# Get latest commit hash
NEW_COMMIT=$(git rev-parse origin/master)

# Read stored commit if it exists
if [[ -f "$COMMIT_FILE" ]]; then
    OLD_COMMIT=$(cat "$COMMIT_FILE")
else
    OLD_COMMIT=""
fi

# Compare commits
if [[ "$NEW_COMMIT" == "$OLD_COMMIT" ]]; then
    echo "✓ Steam udev rules are already up to date (commit: ${NEW_COMMIT:0:7})."
    exit 0
fi

echo "New commit detected (${NEW_COMMIT:0:7}), updating rules..."

# Update to latest commit
git reset --hard origin/master --quiet

# Install the files
cp "60-steam-input.rules" "${UDEV_RULES_DIR}/60-steam-input.rules"
cp "60-steam-vr.rules" "${UDEV_RULES_DIR}/60-steam-vr.rules"

# Set proper permissions
chmod 644 "${UDEV_RULES_DIR}/60-steam-input.rules"
chmod 644 "${UDEV_RULES_DIR}/60-steam-vr.rules"

# Save new commit hash
echo "$NEW_COMMIT" > "$COMMIT_FILE"

# Reload udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

echo ""
echo "✓ Steam udev rules updated successfully!"
echo "Updated from commit ${OLD_COMMIT:0:7} to ${NEW_COMMIT:0:7}"
echo "You may need to log out and back in for changes to take full effect."

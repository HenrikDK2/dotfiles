#!/bin/bash

# LSFG-VK updater for Arch Linux (Pacman)
# Checks GitHub releases and updates if a new version is available
set -e

GITHUB_REPO="PancakeTAS/lsfg-vk"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
STATE_DIR="/var/lib/lsfg-vk"
VERSION_FILE="${STATE_DIR}/installed-version"
INSTALL_DIR="/usr/local"

echo "Checking for LSFG-VK updates..."

# Create state directory if it doesn't exist
mkdir -p "$STATE_DIR"

# Get latest release info from GitHub
RELEASE_JSON=$(curl -s "$GITHUB_API")

if [[ -z "$RELEASE_JSON" ]] || [[ "$RELEASE_JSON" == *"Not Found"* ]]; then
    echo "✗ Failed to fetch release information from GitHub"
    exit 1
fi

# Extract version
LATEST_VERSION=$(echo "$RELEASE_JSON" | grep -m 1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$LATEST_VERSION" ]]; then
    echo "✗ Failed to parse latest version from GitHub"
    exit 1
fi

# Read installed version if it exists
if [[ -f "$VERSION_FILE" ]]; then
    INSTALLED_VERSION=$(cat "$VERSION_FILE")
    echo "Installed version: $INSTALLED_VERSION"
else
    INSTALLED_VERSION=""
    echo "No previous installation detected"
fi

# Compare versions
if [[ "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]; then
    echo "✓ LSFG-VK is already up to date ($LATEST_VERSION)."
    exit 0
fi

echo "New version available, updating to $LATEST_VERSION..."

# Find tar.zst download URL
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*"' | grep "\.tar\.zst" | sed 's/"browser_download_url": *"\([^"]*\)"/\1/' | head -n 1)

if [[ -z "$DOWNLOAD_URL" ]]; then
    echo "✗ Failed to find tar.zst download URL"
    exit 1
fi

echo "Downloading from: $DOWNLOAD_URL"

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download and extract
cd "$TMP_DIR"
curl -L -o lsfg-vk.tar.zst "$DOWNLOAD_URL"
tar --zstd -xf lsfg-vk.tar.zst

# Install files to system
echo "Installing files..."
if [[ -d "usr" ]]; then
    cp -r usr/* "$INSTALL_DIR/"
else
    echo "✗ Unexpected archive structure"
    ls -la
    exit 1
fi

# Save new version
echo "$LATEST_VERSION" > "$VERSION_FILE"

echo ""
echo "✓ LSFG-VK updated successfully!"
echo "Updated from ${INSTALLED_VERSION:-none} to ${LATEST_VERSION}"

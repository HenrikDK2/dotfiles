#!/bin/bash
# Brother laser printer driver (brlaser) installer
# Builds and installs the latest version from source
set -e

PKGNAME="brlaser"
GITHUB_REPO="https://github.com/Owl-Maintain/brlaser.git"
INSTALL_PREFIX="/usr/local"
STATE_DIR="/var/lib/${PKGNAME}"
COMMIT_FILE="${STATE_DIR}/last-commit"
REPO_DIR="${STATE_DIR}/repo"
BUILD_DIR="${STATE_DIR}/build"

# Check and install missing dependencies
DEPENDENCIES=(cups ghostscript cmake gcc make git)
MISSING_DEPS=()

for dep in "${DEPENDENCIES[@]}"; do
    pacman -Qi "$dep" &> /dev/null || MISSING_DEPS+=("$dep")
done

[[ ${#MISSING_DEPS[@]} -gt 0 ]] && pacman -S "${MISSING_DEPS[@]}" --needed --ask 4

# Create state directory if it doesn't exist
mkdir -p "$STATE_DIR"
echo "Checking for updates..."

# Clone or update repository
if [[ -d "$REPO_DIR" ]]; then
    # Repository exists, fetch latest
    cd "$REPO_DIR"
    git fetch origin master --quiet
else
    # Clone repository
    git clone "$GITHUB_REPO" "$REPO_DIR" --quiet
    cd "$REPO_DIR"
fi

# Get latest commit hash on master
NEW_COMMIT=$(git rev-parse origin/master)

# Get latest tag for version display
LATEST_VERSION=$(git describe --tags origin/master 2>/dev/null | sed 's/^v//' || echo "unknown")

echo "Latest version: v${LATEST_VERSION} (commit: ${NEW_COMMIT:0:7})"

# Read stored commit if it exists
if [[ -f "$COMMIT_FILE" ]]; then
    OLD_COMMIT=$(cat "$COMMIT_FILE")
else
    OLD_COMMIT=""
fi

# Compare commits
if [[ "$NEW_COMMIT" == "$OLD_COMMIT" ]] && [[ -n "$OLD_COMMIT" ]]; then
    echo "✓ brlaser is already up to date (commit: ${NEW_COMMIT:0:7})."
    exit 0
fi

if [[ -n "$OLD_COMMIT" ]]; then
    echo "Updating from commit ${OLD_COMMIT:0:7} to ${NEW_COMMIT:0:7}..."
else
    echo "Installing for the first time..."
fi

# Update to latest commit
git reset --hard origin/master --quiet

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build
echo "Building..."
cmake \
    -B "$BUILD_DIR" \
    -S "$REPO_DIR" \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=None \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5

cmake --build "$BUILD_DIR"

# Run tests
echo "Running tests..."
ctest \
    --test-dir "$BUILD_DIR" \
    --output-on-failure \
    --parallel $(nproc) || echo "Warning: Some tests failed, continuing anyway..."

# Install
echo "Installing to ${INSTALL_PREFIX}..."
cmake --install "$BUILD_DIR"

# Save installed commit hash
echo "$NEW_COMMIT" > "$COMMIT_FILE"

echo ""
echo "✓ brlaser v${LATEST_VERSION} installed successfully!"
echo "Installed commit: ${NEW_COMMIT:0:7}"
echo "The driver has been installed to ${INSTALL_PREFIX}"

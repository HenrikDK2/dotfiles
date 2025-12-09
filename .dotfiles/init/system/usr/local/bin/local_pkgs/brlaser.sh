#!/bin/bash
# Brother laser printer driver (brlaser) installer
# Builds and installs the latest version from source
set -e

PKGNAME="brlaser"
URL="https://github.com/Owl-Maintain/brlaser"
INSTALL_PREFIX="/usr/local"
BUILD_DIR="/tmp/${PKGNAME}-build-$$"
STATE_FILE="/var/lib/${PKGNAME}.version"

echo "Installing Brother laser printer driver (brlaser)..."

# Installed dependencies, if needed
pacman -S cups ghostscript cmake gcc make jq curl --needed --ask 4

# Check for CUPS (by checking for cupsd or cups library)
if ! command -v cupsd &> /dev/null && ! pacman -Qi cups &> /dev/null; then
    echo "Error: CUPS is not installed."
    echo "Install with: sudo pacman -S cups"
    exit 1
fi

# Check for ghostscript
if ! command -v gs &> /dev/null && ! pacman -Qi ghostscript &> /dev/null; then
    echo "Error: Ghostscript is not installed."
    echo "Install with: sudo pacman -S ghostscript"
    exit 1
fi

# Fetch latest release info from GitHub
echo "Fetching latest release information..."
LATEST_RELEASE=$(curl -fsSL "https://api.github.com/repos/Owl-Maintain/brlaser/releases/latest")
LATEST_VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tag_name' | sed 's/^v//')

echo "Latest version: v${LATEST_VERSION}"

# Check if already installed
if [[ -f "$STATE_FILE" ]]; then
    INSTALLED_VER=$(cat "$STATE_FILE")
    if [[ "$INSTALLED_VER" == "$LATEST_VERSION" ]]; then
        echo "✓ brlaser v${LATEST_VERSION} is already installed (latest version)."
        exit 0
    fi
    echo "Updating from v${INSTALLED_VER} to v${LATEST_VERSION}..."
fi

# Create build directory
mkdir -p "$BUILD_DIR"
trap "rm -rf $BUILD_DIR" EXIT

cd "$BUILD_DIR"

# Download source (using the standard release archive URL)
echo "Downloading source..."
curl -fsSL "${URL}/archive/refs/tags/v${LATEST_VERSION}.tar.gz" -o "${PKGNAME}.tar.gz"

# Extract source
echo "Extracting source..."
tar -xzf "${PKGNAME}.tar.gz"

# Build
echo "Building..."
cmake \
    -B build \
    -S "${PKGNAME}-${LATEST_VERSION}" \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=None \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5

cmake --build build

# Run tests
echo "Running tests..."
ctest \
    --test-dir build \
    --output-on-failure \
    --parallel $(nproc) || echo "Warning: Some tests failed, continuing anyway..."

# Install
echo "Installing to ${INSTALL_PREFIX}..."
cmake --install build

# Save installed version
echo "$LATEST_VERSION" > "$STATE_FILE"

echo ""
echo "✓ brlaser v${LATEST_VERSION} installed successfully!"
echo "The driver has been installed to ${INSTALL_PREFIX}"

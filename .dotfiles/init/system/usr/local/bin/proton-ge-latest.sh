function update_proton_ge() {
    local PROTON_DIR="/usr/share/steam/compatibilitytools.d/ProtonGE-latest"
    local TEMP_DIR="/tmp/proton-ge-temp"
    local INSTALLED_TAG_FILE="$PROTON_DIR/.installed_tag"
    local TMP_TAR="/tmp/proton-ge-custom-latest.tar.gz"
    local API_URL="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
	local VDF_FILE="$PROTON_DIR/compatibilitytool.vdf"
    local RELEASE_INFO
    local RELEASE_TAG
    local ASSET_URL
    local TEMP_EXTRACT_DIR

    echo "Checking latest Proton GE release..."
    RELEASE_INFO=$(curl -s "$API_URL")
    RELEASE_TAG=$(echo "$RELEASE_INFO" | grep '"tag_name":' | head -n1 | cut -d '"' -f4)
    ASSET_URL=$(echo "$RELEASE_INFO" | grep "browser_download_url" | grep ".tar.gz" | cut -d '"' -f4)

    if [ -z "$RELEASE_TAG" ] || [ -z "$ASSET_URL" ]; then
        echo "Failed to fetch release info. Exiting."
        return 1
    fi

    echo "Latest release: $RELEASE_TAG"

    # Compare with installed version
    if [ -f "$INSTALLED_TAG_FILE" ] && [ "$(cat "$INSTALLED_TAG_FILE")" == "$RELEASE_TAG" ]; then
        echo "Proton GE is already up to date."
        return 0
    fi

    # Download new release
    echo "Downloading new release..."
    curl -L -o "$TMP_TAR" "$ASSET_URL"


    # Create a temporary directory to extract the tarball
    mkdir -p "$TEMP_DIR"
    
    # Extract tarball to the temporary directory
    echo "Extracting release..."
    tar -xvf "$TMP_TAR" -C "$TEMP_DIR" --strip-components=1

    # Now, move the extracted files to the fixed ProtonGE-latest directory
    echo "Installing Proton GE into $PROTON_DIR..."
    rm -rf "$PROTON_DIR" && mkdir -p "$PROTON_DIR"
    mv "$TEMP_DIR"/* "$PROTON_DIR/"

	if [ -f "$VDF_FILE" ]; then
	     echo "Updating display_name in compatibilitytool.vdf..."
	     sed -i 's/"display_name"[[:space:]]*"[^"]*"/"display_name" "GE-Proton-latest"/g' "$VDF_FILE"
	fi

    # Save release tag for future checks
    echo "$RELEASE_TAG" > "$INSTALLED_TAG_FILE"

    # Set permissions
    chown -R root:root "$PROTON_DIR"
    chmod -R 755 "$PROTON_DIR"

    # Clean up
    rm -rf "$TEMP_DIR"
    rm "$TMP_TAR"

    echo "Proton GE $RELEASE_TAG has been installed successfully as ProtonGE-latest."
}

update_proton_ge

#!/bin/bash
set -euo pipefail -o noclobber
IFS=$'\n\t'

# Network check function with max attempts
wait_for_network() {
    local max_attempts=10
    local attempt=0

    echo "Checking network connection (max $max_attempts attempts)..."

    while (( attempt++ < max_attempts )); do
        if ping -c 1 -W 3 8.8.8.8 &>/dev/null || \
           ping -c 1 -W 3 1.1.1.1 &>/dev/null || \
           curl -fs --connect-timeout 3 http://captive.apple.com &>/dev/null; then
            echo "Network connection established"
            return 0
        fi

        echo "Attempt $attempt/$max_attempts - Waiting for network..."
        sleep 30
    done

    echo "❌ Error: Network connection failed after $max_attempts attempts" >&2
    return 1
}

# Wait for network before proceeding
wait_for_network || exit 1

# Flatpak updates
if command -v flatpak &>/dev/null; then
    echo "Updating Flatpaks..."
    flatpak update --noninteractive --assumeyes
fi

# System packages updates
echo "Updating system..."
pacman -Syu --ask 4 
echo "✅ Update process finished."
exit 0

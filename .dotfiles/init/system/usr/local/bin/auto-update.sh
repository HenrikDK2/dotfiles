#!/bin/bash
set -euo pipefail -o noclobber
IFS=$'\n\t'

UPDATE_INTERVAL_FILE="/var/tmp/update_script_last_run"
UPDATE_INTERVAL=$((24 * 60 * 60))  # 24 hours

# Network check function with max attempts
function wait_for_network() {
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

function exit_if_updated_recently() {
    local now=$(date +%s)

    if [[ -f "$UPDATE_INTERVAL_FILE" ]]; then
        local last_run=$(stat -c %Y "$UPDATE_INTERVAL_FILE")
        local age=$((now - last_run))

        if (( age < UPDATE_INTERVAL )); then
            echo "Last successful update was $age seconds ago (< 24h). Skipping..."
            exit 0
        fi
    fi
}

# Enforce 24h update interval
exit_if_updated_recently

# Wait for network before proceeding
wait_for_network || exit 1

# System packages updates
pacman -Syu --ask 4 

# Flatpak updates
if command -v flatpak &>/dev/null; then
    echo "Updating Flatpaks..."
    flatpak update --noninteractive --assumeyes
fi

# Update local_pkgs
/usr/local/bin/local_pkgs/main.sh

# Create time stamp, if successful
touch "$UPDATE_INTERVAL_FILE"

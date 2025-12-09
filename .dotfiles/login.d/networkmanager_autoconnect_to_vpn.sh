#!/bin/bash

sleep 2

# Get the primary device (default route)
PRIMARY_DEV=$(ip route | grep '^default' | awk '{print $5}')

# Get the active connection name for the primary device
PRIMARY_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | grep "$PRIMARY_DEV" | cut -d: -f1)

# Check if primary connection exists
if [ -n "$PRIMARY_CONN" ]; then
    echo "Primary connection '$PRIMARY_CONN' is active on device $PRIMARY_DEV."

    # Extract secondary VPN UUID from primary connection
    SECONDARY_UUID=$(nmcli connection show "$PRIMARY_CONN" | grep '^connection.secondaries:' | awk '{print $2}')

    if [ -n "$SECONDARY_UUID" ]; then
        echo "Found secondary VPN UUID: $SECONDARY_UUID"
        echo "Connecting to secondary VPN..."
        nmcli connection up uuid "$SECONDARY_UUID"

        # Verify if VPN connected successfully
        if nmcli connection show --active | grep -q "$SECONDARY_UUID"; then
            echo "Secondary VPN $SECONDARY_UUID connected successfully."
        else
            echo "Failed to connect to secondary VPN $SECONDARY_UUID."
        fi
    else
        echo "No secondary VPN defined in primary connection. Skipping."
    fi
fi

#!/bin/bash

# Run all login scripts in background
for script in $HOME/.dotfiles/login.d/*.sh; do
    "$script" &
done

# Start background services
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
mako &
nm-applet &

# Wait for primary connection
echo "Waiting for primary network connection..."
PRIMARY_CONN=""
TIMEOUT=10
ELAPSED=0

while [ -z "$PRIMARY_CONN" ] && [ $ELAPSED -lt $TIMEOUT ]; do
    PRIMARY_DEV=$(ip route | grep '^default' | awk '{print $5}')

    if [ -n "$PRIMARY_DEV" ]; then
        PRIMARY_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | grep "$PRIMARY_DEV" | cut -d: -f1)
        
        # If PRIMARY_CONN is still empty, check if the connection ID exists in nmcli
        if [ -z "$PRIMARY_CONN" ]; then
            TIME_LEFT=$((TIMEOUT - ELAPSED))
            START_WAIT=$(date +%s)
            
            until nmcli connection show | awk '{print $1}' | grep -qx "$PRIMARY_DEV" || [ $(( $(date +%s) - START_WAIT )) -ge $TIME_LEFT ]; do
                sleep 1
            done
        fi
    fi

    ELAPSED=$((ELAPSED + 1))
done

# Get default VPN connection (auto in networkmanager)
SECONDARY_UUID=$(nmcli connection show "$PRIMARY_CONN" | grep '^connection.secondaries:' | awk '{print $2}')

# Wait for VPN if defined
if [ -n "$SECONDARY_UUID" ]; then
    sleep 2 # Need a buffer before connection to VPN
    nmcli connection up uuid "$SECONDARY_UUID"
    
    # Wait until VPN is active
    while ! nmcli connection show --active | grep -q "$SECONDARY_UUID" && [ $ELAPSED -lt $TIMEOUT ]; do
        sleep 1
        ELAPSED=$((ELAPSED + 1))
    done
fi

# Launch applications
hyprctl dispatch exec "[workspace 2 silent] thunderbird" &

# Wait until Thunderbird window appears
until hyprctl clients | grep "Thunderbird"; do
    sleep 1
done

# Start other apps
hyprctl dispatch exec "[workspace 2 silent] discord" &
hyprctl dispatch exec "[workspace 2 silent] steam" &

# Run audit script
sleep 2
$HOME/.my_scripts/scripts/audit.sh -q

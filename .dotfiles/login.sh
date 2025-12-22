#!/bin/bash

hyprlock

# Run all login scripts in background
for script in $HOME/.dotfiles/login.d/*.sh; do
   "$script" &
done

# Start background services
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
mako &
nm-applet &

# Connect to primary network
PRIMARY_CONN=$(nmcli -t -f NAME,AUTOCONNECT connection show | grep -v "lo" | grep ":yes" | head -n 1 | cut -d: -f1)

if [ -n "$PRIMARY_CONN" ]; then
    nmcli connection up "$PRIMARY_CONN" 2>/dev/null
    
    # Wait for connection (max 10s)
    for i in {1..10}; do
        if nmcli -t -f NAME,STATE connection show --active | grep -q "^${PRIMARY_CONN}:activated$"; then
            echo "Connected to $PRIMARY_CONN (${i}s)"
            break
        fi
        sleep 1
    done
    
    # Connect to VPN if configured
    SECONDARY_UUID=$(nmcli -t -f connection.secondaries connection show "$PRIMARY_CONN" | cut -d: -f2)
    
    if [ -n "$SECONDARY_UUID" ]; then
        sleep 2
        nmcli connection up uuid "$SECONDARY_UUID"
        
        # Wait for VPN (max 10s)
        for i in {1..10}; do
            nmcli connection show --active | grep -q "$SECONDARY_UUID" && break
            sleep 1
        done
    fi
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

# Audit script to check for system issues (Only runs in foreground if detected)
$HOME/.dotfiles/scripts/audit.sh -b

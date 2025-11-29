#!/bin/bash

for script in $HOME/.my_scripts/login.d/*.sh; do "$script" & done
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
mako &

# Wait for privateinternetaccess to connect to VPN
if command -v piactl >/dev/null 2>&1; then
    while [ "$(piactl get connectionstate)" != "Connected" ]; do
        sleep 1
    done
fi

# Open default application windows
hyprctl dispatch exec "[workspace 2 silent] thunderbird" &

until hyprctl clients | grep "Thunderbird"; do
	sleep 1
done

hyprctl dispatch exec "[workspace 2 silent] discord" &
hyprctl dispatch exec "[workspace 2 silent] steam" &

# Check for errors in audit script
sleep 2
$HOME/.my_scripts/scripts/audit.sh -q

#!/bin/sh

launch () {
    uppercase=${1^}
    if [ -z "$(pidof $1)" ] && [ -z "$(pidof $uppercase)" ]; then
        nohup $1 > /dev/null 2>&1 &
    fi
}

# Programs to lauch at login (executable)
exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
launch corectrl
launch mako
launch waybar 
launch evolution
launch discord

# Launch optimization script for priorities
sleep 10
sudo ~/.my_scripts/optimize.sh
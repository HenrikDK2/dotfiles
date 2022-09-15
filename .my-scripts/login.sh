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
sleep 20
launch evolution
launch discord

# Reduce priority of this script
renice -n 20 $$
ionice -c idle -p $$

# Priority of processes (name, niceness, ionice class)
while true; do
    ~/.my-scripts/prio.sh
done

#!/bin/bash

for script in $HOME/.dotfiles/login.d/*.sh; do "$script" & done
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
mako &
nm-applet &

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

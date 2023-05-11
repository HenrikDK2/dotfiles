#!/bin/sh

# Programs to lauch at login (executable)
(/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &)
(mako &)
(waybar &) 
(evolution &)
(discord &)

# Reduce priority of this script
renice -n 20 $$
ionice -c idle -p $$

# Custom bash scripts within ~/.my_scripts/login.d will load at session start
for script in ~/.my_scripts/login.d/*.sh; do "$script" & done

# Launch optimization script for priorities
sleep 10
sudo /usr/local/bin/gamemode/optimize.sh

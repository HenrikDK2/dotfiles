#!/bin/bash

# Custom bash scripts within ~/.my_scripts/login.d will load at session start
for script in $HOME/.my_scripts/login.d/*.sh; do "$script" & done

# Programs to lauch at login (executable)
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
mako &
waybar &
thunderbird &
discord &
discord-canary &

# Improve scheduling in Sway and Gamescope (run in parallel)
setcap 'cap_sys_nice=eip' /usr/bin/sway &
setcap 'cap_sys_nice=eip' /usr/bin/gamescope &

# Switch to workspace 1
swaymsg workspace number 1

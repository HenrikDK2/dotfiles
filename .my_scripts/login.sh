#!/bin/sh

# Programs to lauch at login (executable)

(exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &)
(exec /usr/local/bin/swayidle.sh &)
(exec mako &)
(exec waybar &) 
(exec evolution &)
(exec discord -enable-features=UseOzonePlatform -ozone-platform=wayland &)

# Reduce priority of this script
renice -n 20 $$
ionice -c idle -p $$


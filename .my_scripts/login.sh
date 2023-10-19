#!/bin/bash

# First login (Post-install)
if [ ! -f .config/fish/.post-install ]; then
	dconf write /org/nemo/window-state/start-with-menu-bar false
	dconf write /org/gnome/evolution/shell/menubar-visible false
	dconf write /org/gnome/evolution/shell/statusbar-visible false
	dconf write /org/gnome/evolution/shell/toolbar-visible false
	dconf write /org/gnome/evolution/mail/show-preview-toolbar false
	dconf write /org/gnome/evolution/shell/buttons-style "'icons'"
	dconf write /org/gnome/evolution/shell/toolbar-icon-size "'small'"
	touch .config/fish/.post-install
fi

# Custom bash scripts within ~/.my_scripts/login.d will load at session start
for script in ~/.my_scripts/login.d/*.sh; do (exec "$script" &) done

# Programs to lauch at login (executable)
(exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &)
(exec mako &)
(exec waybar &) 
(exec evolution &)
(exec discord -enable-features=UseOzonePlatform -ozone-platform=wayland &)

# Reduce priority of this script
renice -n 20 $$
ionice -c idle -p $$

# Optimize priorities of processes
sleep 10
sudo /usr/local/bin/gamemode/optimize.sh &

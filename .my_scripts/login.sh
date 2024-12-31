#!/bin/bash

# First login (Post-install)
if [ ! -f $HOME/.config/.post-install ]; then
	dconf write /org/nemo/window-state/start-with-menu-bar false
	dconf write /org/gnome/evolution/shell/menubar-visible false
	dconf write /org/gnome/evolution/shell/statusbar-visible false
	dconf write /org/gnome/evolution/shell/toolbar-visible false
	dconf write /org/gnome/evolution/mail/show-preview-toolbar false
	dconf write /org/gnome/evolution/shell/buttons-style "'icons'"
	dconf write /org/gnome/evolution/shell/toolbar-icon-size "'small'"
	touch $HOME/.config/.post-install
fi

# Make sure VPN script is loaded as quickly as possible
$HOME/.my_scripts/login.d/vpn.sh

# Custom bash scripts within ~/.my_scripts/login.d will load at session start
for script in $HOME/.my_scripts/login.d/*.sh; do (exec "$script" &) done

# Programs to lauch at login (executable)
(/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &)
(mako &)
(waybar &) 
(thunderbird &)
(discord &)
(discord-canary &)

# Improve scheduling in Sway and Gamescope (run in parallel)
setcap 'cap_sys_nice=eip' /usr/bin/sway &
setcap 'cap_sys_nice=eip' /usr/bin/gamescope &

# Switch to workspace 1
swaymsg workspace number 1


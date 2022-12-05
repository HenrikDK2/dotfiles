#!/bin/sh

launch () {
    uppercase=${1^}
    if [ -z "$(pidof $1)" ] && [ -z "$(pidof $uppercase)" ]; then
        nohup $1 > /dev/null 2>&1 &
    fi
}

# Programs to lauch at login (executable)
exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
launch mako
launch waybar 
launch evolution
launch discord

# Custom bash scripts within ~/.my_scripts/login.d will load at session start
for script in ~/.my_scripts/login.d/*.sh; do "$script" & done

# Launch optimization script for priorities
sleep 10
sudo ~/.my_scripts/gamemode/optimize.sh

# Install vscode plugins (It will not install if already installed)
~/.my_scripts/init/code-extensions.sh

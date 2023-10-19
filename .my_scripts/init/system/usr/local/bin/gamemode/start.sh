#!/bin/sh

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
source "$parent_path/optimize.sh"

stop_service () {
    while [ -n "$(systemctl --state=running | grep "$1")" ]; do
        if [ -z "$2" ]; then sudo systemctl stop $1; else sudo systemctl stop $2; fi
    done
}

# Kills cmst (Kill the front-end for connman, it usually runs in the background, but is not needed)
killall -9 cmst

# Kill bluez front-end
killall -9 blueman-applet blueman-manager blueman-tray

# Stop services using memory while not needed
stop_service upower
stop_service cups
stop_service journald systemd-journald systemd-journald.socket systemd-journald-dev-log.socket systemd-journald-audit.socket
stop_service systemd-timesyncd
stop_service rtkit-daemon

# Only stop services related to virt-manager if closed
if [ -z "$(pgrep virt-manager)" ]; then
	stop_service systemd-machined
	stop_service virtlogd
	stop_service libvirtd libvirtd.service libvirtd-admin.socket libvirtd-ro.socket libvirtd.socket
fi

# Stop docker if no containers are running
if [[ -z $(sudo docker ps -q) ]]; then
  stop_service docker
fi

for script in $parent_path/start.d/*.sh; do "$script" & done

sleep 60

# Games - Same priority as gamemode
set_prio "steamapps/common/" -10 1 0
set_prio "/*[.]exe" -10 1 0
set_prio "obs" -10 1 0

# Stop steamwebhelper from taking resources from the game
set_prio "steamwebhelper" 10 3

# Lower priority of WINE proccesses that are unrelated to the game
set_prio "tabtip.exe" -5 2 0
set_prio "wineserver" -5 2 0
set_prio "explorer.exe" -5 2 0
set_prio "plugplay.exe" -5 2 0
set_prio "winedevice.exe" -5 2 0
set_prio "services.exe" -5 2 0
set_prio "start.exe" -5 2 0
set_prio "rpcss.exe" -5 2 0

#!/bin/sh

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
source "$parent_path/optimize.sh"

stop_service () {
    while [ -n "$(systemctl --state=running | grep "$1")" ]; do
        if [ -z "$2" ]; then sudo systemctl stop $1; else sudo systemctl stop $2; fi
    done
}

stop_service cups
stop_service journald systemd-journald systemd-journald.socket systemd-journald-dev-log.socket systemd-journald-audit.socket
stop_service systemd-timesyncd

# Only stop services related to virt-manager if closed
if [ -z "$(pgrep virt-manager)" ]; then
	stop_service systemd-machined
	stop_service virtlogd
	stop_service libvirtd libvirtd.service libvirtd-admin.socket libvirtd-ro.socket libvirtd.socket
fi

# Clear RAM
kill $(pgrep chrome_crashpad)
sudo sh -c 'echo 3 >  /proc/sys/vm/drop_caches'

sleep 60

# Games - Same priority as gamemode
set_prio "steamapps/common/" -10 1 0
set_prio "/*[.]exe" -10 1 0
set_prio "obs" -10 1 0

# Lower priority of WINE proccesses that are unrelated to the game
set_prio "tabtip.exe" -5 2 0
set_prio "wineserver" -5 2 0
set_prio "explorer.exe" -5 2 0
set_prio "plugplay.exe" -5 2 0
set_prio "winedevice.exe" -5 2 0
set_prio "services.exe" -5 2 0
set_prio "start.exe" -5 2 0
set_prio "rpcss.exe" -5 2 0

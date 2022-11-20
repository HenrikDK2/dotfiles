#!/bin/sh

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
source "$parent_path/optimize.sh"

while [ -n "$(systemctl --state=running | grep "journald")" ]; do
    sudo systemctl stop systemd-journald systemd-journald.socket systemd-journald-dev-log.socket systemd-journald-audit.socket
done

while [ -n "$(systemctl --state=running | grep "cups")" ]; do
    sudo systemctl stop cups
done

# Clear RAM
sudo sh -c 'echo 3 >  /proc/sys/vm/drop_caches'

sleep 60

# Games - Same priority as gamemode
set_prio "steamapps/common/" -10 1 0
set_prio "/*[.]exe" -10 1 0
set_prio "obs" -10 1 0

# Lower WINE proccesses
set_prio "tabtip.exe" -5 2 0
set_prio "wineserver" -5 2 0
set_prio "explorer.exe" -5 2 0
set_prio "plugplay.exe" -5 2 0
set_prio "winedevice.exe" -5 2 0
set_prio "services.exe" -5 2 0
set_prio "start.exe" -5 2 0
set_prio "rpcss.exe" -5 2 0

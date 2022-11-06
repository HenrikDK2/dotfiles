#!/bin/sh

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
source "$parent_path/optimize.sh"

while [ -n "$(systemctl --state=running | grep "journald")" ]; do
    sudo systemctl stop systemd-journald systemd-journald.socket systemd-journald-dev-log.socket systemd-journald-audit.socket
done

# Clear RAM
sudo sh -c 'echo 3 >  /proc/sys/vm/drop_caches'

sleep 30

# Games - Same priority as gamemode
set_prio "steamapps/common/" -10 1 0
set_prio "/*[.]exe" -10 1 0
set_prio "obs" -10 1 0

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

# Disable split lock mitigation for performance gain in some games, is enabled again on game exit. 
sudo sysctl kernel.split_lock_mitigate=0

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

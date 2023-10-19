#!/bin/sh

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
source "$parent_path/optimize.sh"

for script in $parent_path/exit.d/*.sh; do "$script" & done

sudo systemctl start upower
sudo systemctl start systemd-journald cups systemd-timesyncd
sudo systemctl start libvirtd virtlogd
sudo systemctl start docker
sudo systemctl start rtkit-daemon

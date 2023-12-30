#!/bin/sh

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
source "$parent_path/optimize.sh"

sudo systemctl start upower
sudo systemctl start systemd-journald cups systemd-timesyncd
sudo systemctl start libvirtd virtlogd
sudo systemctl start docker

# Re-enable split lock mitigation
sudo sysctl kernel.split_lock_mitigate=1

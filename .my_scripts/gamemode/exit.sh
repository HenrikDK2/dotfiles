#!/bin/sh

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
source "$parent_path/optimize.sh"

sudo systemctl start systemd-journald cups systemd-timesyncd
sudo systemctl start libvirtd

# Clear RAM
sudo sh -c 'echo 3 >  /proc/sys/vm/drop_caches'

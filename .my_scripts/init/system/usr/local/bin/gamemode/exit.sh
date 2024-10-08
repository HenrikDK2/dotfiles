#!/bin/sh

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
source "$parent_path/optimize.sh"

sudo systemctl start upower
sudo systemctl start systemd-journald.service
sudo systemctl start cups systemd-timesyncd
sudo systemctl start libvirtd virtlogd
sudo systemctl start docker
sudo systemctl start containerd

# Re-enable split lock mitigation
sudo sysctl kernel.split_lock_mitigate=1

# Set performance level to auto
for card_dir in /sys/class/drm/card*; do
	power_dpm="$card_dir/device/power_dpm_force_performance_level"
	
    if [ -e "$power_dpm" ]; then
        echo "auto" | sudo tee $power_dpm
  	fi
done

# Sometimes proton doesn't exit correctly, and leaves unwanted processes behind
# This wil kill all wine-related processes
ps aux | awk '/\.exe$/ {print $2}' | xargs kill
pkill -f wine

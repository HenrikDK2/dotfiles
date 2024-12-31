#!/bin/sh

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
source "$parent_path/optimize.sh"

systemctl start upower
systemctl start systemd-journald.service
systemctl start cups systemd-timesyncd
systemctl start libvirtd virtlogd
systemctl start docker
systemctl start containerd

# Re-enable split lock mitigation
sysctl kernel.split_lock_mitigate=1

# Set CPU governor to ondemand if available, else powersave
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if grep -q "ondemand" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
        echo "ondemand" | tee $cpu
    else
        echo "powersave" | tee $cpu
    fi
done

# Enable CPU Idle C-states
echo 0 > /sys/devices/system/cpu/cpu*/cpuidle/state*/disable

# Set performance level to auto
for card_dir in /sys/class/drm/card*; do
	power_dpm="$card_dir/device/power_dpm_force_performance_level"
	
    if [ -e "$power_dpm" ]; then
        echo "auto" | tee $power_dpm
  	fi
done

# Sometimes proton doesn't exit correctly, and leaves unwanted processes behind
# This will kill all wine-related processes
ps aux | awk '/\.exe$/ {print $2}' | xargs kill
pkill -f wine

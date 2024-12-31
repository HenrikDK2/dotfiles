#!/bin/sh

# Start required services in parallel
systemctl start upower systemd-journald.service cups systemd-timesyncd libvirtd virtlogd docker containerd &

# Re-enable split lock mitigation
sysctl kernel.split_lock_mitigate=1

# Set CPU governor to ondemand if available, else powersave
governor="powersave"
if grep -q "ondemand" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
    governor="ondemand"
fi
find /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor -exec echo "$governor" > {} \;

# Enable CPU Idle C-states
for cpu in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    echo 0 > "$cpu"
done

# Set performance level to auto for GPUs if applicable
for card_dir in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
    if [ -e "$card_dir" ]; then
        echo "auto" > "$card_dir"
    fi
done

# Kill all wine-related processes
pkill -f '\.exe$'

# Clear RAM
pkill chrome_crashpad
echo 3 > /proc/sys/vm/drop_caches

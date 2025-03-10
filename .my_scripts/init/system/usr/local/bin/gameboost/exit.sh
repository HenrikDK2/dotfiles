#!/bin/sh

# Start required services in parallel
systemctl start upower systemd-journald.service cups systemd-timesyncd libvirtd virtlogd docker containerd &

# Re-enable split lock mitigation
sysctl kernel.split_lock_mitigate=1

# Set THP to 'madvise' to reduce memory impact
echo 'madvise' | tee /sys/kernel/mm/transparent_hugepage/enabled

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

# Set AMD GPU to auto when not gaming
GPU=$(lspci | awk '/VGA|3D/{print "/sys/bus/pci/devices/0000:"$1}')

if [ -d "$GPU" ]; then
	power_dpm="$GPU/power_dpm_force_performance_level"
	aspm="$GPU/power/control"

	[ -f "$power_dpm" ] && echo "auto" | tee "$power_dpm" > /dev/null 2>&1 
	[ -f "$aspm" ] && echo "auto" | tee "$aspm" > /dev/null 2>&1
fi

# Clear RAM
pkill chrome_crashpad
echo 3 > /proc/sys/vm/drop_caches

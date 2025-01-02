#!/bin/sh

# Adjust priorities of pids passed from main.sh
pids="$1 $(pgrep -f '\.exe' || true)"
renice -n -11 -p $pids >/dev/null 2>&1

# Set CPU governor to performance
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 &

# Set AMD GPU to maximum performance level during gaming (reduce stutters)
for card_dir in /sys/class/drm/card*; do
    power_dpm="$card_dir/device/power_dpm_force_performance_level"
    pp_power="$card_dir/device/pp_power_profile_mode"
    
    if [[ -e "$power_dpm" && -e "$pp_power" ]]; then
        echo "manual" | tee $power_dpm > /dev/null 2>&1 &
        echo "1" | tee $pp_power > /dev/null 2>&1 &
    fi
done

# Disable CPU Idle C-states
for cpu in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    echo 1 > "$cpu"
done

# THP reduces memory management and improves performance
echo 'always' | tee /sys/kernel/mm/transparent_hugepage/enabled

# Kill unnecessary background processes
killall -9 cmst mullvad-gui blueman-applet blueman-manager blueman-tray

# Stop services in parallel
systemctl stop upower &
systemctl stop cups &
systemctl stop systemd-journald.socket &
systemctl stop systemd-journald-dev-log.socket &
systemctl stop systemd-journald-audit.socket &
systemctl stop systemd-journald &
systemctl stop systemd-timesyncd &

# Disable split lock mitigation
sysctl kernel.split_lock_mitigate=0 &

# Stop virt-manager related services only if closed
if [ -z "$(pgrep virt-manager)" ]; then
	systemctl stop libvirtd-admin.socket &
	systemctl stop libvirtd-ro.socket &
	systemctl stop libvirtd.socket &
	systemctl stop libvirtd &
fi

# Stop docker services if no containers are running
if [[ -z $(docker ps -q) ]]; then
  systemctl stop docker &
  systemctl stop containerd &
fi

# Clear RAM (in parallel)
kill $(pgrep chrome_crashpad) &
sh -c 'echo 3 > /proc/sys/vm/drop_caches' &

# Sometimes memory clock isn't using the overclocked value
# The function below fixes that issue
if systemctl is-enabled amd-overclock.service &>/dev/null; then
	source /usr/local/bin/amd-overclock.sh
    
    if [ ! -z "$MEMORY_CLOCK" ]; then
    	while true; do
    		CURRENT_MEMORY_SPEED=$(grep '*' "$GPU/pp_dpm_mclk" | awk '{print $2}')
    
    		# Empty means the memory speed is running at a custom speed.
    		# And that indicates that the gpu is running at the overclocked memory speed.
    		if [[ "$CURRENT_MEMORY_SPEED" == "" ]]; then
    			break;
    		fi
    
    		echo "m 1 $(($MEMORY_CLOCK + 1))" > $PP_OD_CLK_VOLTAGE
    		echo "c" > $PP_OD_CLK_VOLTAGE
    		sleep 5
    		echo "m 1 $MEMORY_CLOCK" > $PP_OD_CLK_VOLTAGE
    		echo "c" > $PP_OD_CLK_VOLTAGE
    		sleep 10
    	done
    fi
fi

wait

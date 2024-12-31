#!/bin/sh

stop_service () {
	systemctl stop $1;
}

# Set CPU govenor to performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" | tee $cpu
done

# Set AMD gpu to maximum performance level during gaming (Reduce stutters)
for card_dir in /sys/class/drm/card*; do
	power_dpm="$card_dir/device/power_dpm_force_performance_level"
	pp_power="$card_dir/device/pp_power_profile_mode"
	
    if [[ -e "$power_dpm" && -e "$pp_power" ]]; then
        echo "manual" | tee $power_dpm
        echo "1" | tee $pp_power
  	fi
done

# Disable CPU Idle C-states (for better responsiveness)
echo 1 > /sys/devices/system/cpu/cpu*/cpuidle/state*/disable

# Kills cmst (Kill the front-end for connman, it usually runs in the background, but is not needed)
killall -9 cmst

# Killed mullvad vpn graphical interface (the daemon still runs)
killall -9 mullvad-gui

# Kill bluez front-end
killall -9 blueman-applet blueman-manager blueman-tray

# Stop services using memory while not needed
stop_service upower
stop_service cups
stop_service systemd-journald.socket
stop_service systemd-journald-dev-log.socket
stop_service systemd-journald-audit.socket
stop_service systemd-journald
stop_service systemd-timesyncd

# Disable split lock mitigation for performance gain in some games, is enabled again on game exit. 
sysctl kernel.split_lock_mitigate=0

# Only stop services related to virt-manager if closed
if [ -z "$(pgrep virt-manager)" ]; then
	stop_service libvirtd-admin.socket
	stop_service libvirtd-ro.socket
	stop_service libvirtd.socket
	stop_service libvirtd
fi

# Stop docker if no containers are running
if [[ -z $(docker ps -q) ]]; then
  stop_service docker
  stop_service containerd
fi

# Improve scheduling in Sway and Gamescope
setcap 'cap_sys_nice=eip' /usr/bin/sway
setcap 'cap_sys_nice=eip' /usr/bin/gamescope

# Clear RAM
kill $(pgrep chrome_crashpad)
sh -c 'echo 3 >  /proc/sys/vm/drop_caches'

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
    		sleep 5
    	done
    fi
fi

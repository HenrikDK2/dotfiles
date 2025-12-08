#!/bin/bash

# Adjust priorities of pids passed from main.sh
for pid in "$@"; do
	renice -n -11 -p "$pid" >/dev/null 2>&1
	ionice -c 1 -n 0 -p "$pid" >/dev/null 2>&1
done

# Set CPU governor to performance
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null

# AMD GPU max performance
GPU=$(lspci | awk '/VGA|3D/{print "/sys/bus/pci/devices/0000:"$1}')

if [ -d "$GPU" ]; then
    [ -f "$GPU/power_dpm_force_performance_level" ] && echo "manual" > "$GPU/power_dpm_force_performance_level"
    [ -f "$GPU/power/control" ] && echo "on" > "$GPU/power/control"
    [ -f "$GPU/pp_power_profile_mode" ] && echo "1" > "$GPU/pp_power_profile_mode"
fi

# Stop unnecessary background processes
processes=(cmst mullvad-gui blueman-applet blueman-manager blueman-tray chrome_crashpad)
for p in "${processes[@]}"; do
    pkill -9 "$p" 2>/dev/null
done

# Stop system services
system_services=(
    systemd-journald.socket
    systemd-journald-dev-log.socket
    systemd-journald-audit.socket
    systemd-journald

    clamav-daemon.socket
    clamav-daemon
    clamav-freshclam

    libvirtd-admin.socket
    libvirtd-ro.socket
    libvirtd.socket
    libvirtd

    cups
    avahi-daemon

    udisks2
    upower
    systemd-timesyncd
    docker
    containerd
)

# Stop user services
user_services=(
    gvfs-daemon
    gvfs-metadata
)

# Get all active user IDs with sessions
user_ids=($(loginctl list-sessions --no-legend | awk '{print $2}' | sort -u))

# Mask upower
systemctl mask upower.service 2>/dev/null

for ((i=0; i<3; i++)); do
    any_active=false

    # Stop system services
    for svc in "${system_services[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            any_active=true
            systemctl stop "$svc" 2>/dev/null || true
        fi
    done

    # Stop user services for all active sessions
    for uid in "${user_ids[@]}"; do
        for svc in "${user_services[@]}"; do
            if systemctl --user --machine=${uid}@.host is-active --quiet "$svc"; then
                any_active=true
                systemctl --user --machine=${uid}@.host stop "$svc"
            fi
        done
    done

    [ "$any_active" = false ] && break
    sleep 1
done

# Clear RAM
pkill -9 chrome_crashpad
echo 3 > /proc/sys/vm/drop_caches

#!/bin/bash

# Adjust priorities of pids passed from main.sh
for pid in "$@"; do
	renice -n -11 -p "$pid" >/dev/null 2>&1
	ionice -c 1 -n 0 -p "$pid" >/dev/null 2>&1
done

# Set CPU governor to performance
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
[ -f /sys/devices/system/cpu/amd_pstate/status ] && echo "active" > /sys/devices/system/cpu/amd_pstate/status

# AMD GPU max performance
GPU=$(lspci | awk '/VGA|3D/{print "/sys/bus/pci/devices/0000:"$1}')

if [ -d "$GPU" ]; then
    [ -f "$GPU/power_dpm_force_performance_level" ] && echo "manual" > "$GPU/power_dpm_force_performance_level"
    [ -f "$GPU/power/control" ] && echo "on" > "$GPU/power/control"
    [ -f "$GPU/pp_power_profile_mode" ] && echo "1" > "$GPU/pp_power_profile_mode"
fi

# Disabling SELinux while playing games
setenforce 0

# Stop unnecessary background processes
processes=(cmst mullvad-gui blueman-applet blueman-manager blueman-tray chrome_crashpad)
for p in "${processes[@]}"; do
    pkill -9 "$p" 2>/dev/nully
done

# Stop system services
system_services=(
	# DONT STOP JOURNALD SERVICES, CAUSES SYSTEM CRASH WITH COSMIC NETWORK APPLET
    #systemd-journald.socket
    #systemd-journald-dev-log.socket
    #systemd-journald-audit.socket
    #systemd-journald.service

    abrtd.service
    abrt-journal-core.service
    abrt-oops.service
    abrt-xorg.service

    avahi-daemon.service
    avahi-daemon.socket
   	cups.service

    auditd.service

   	alsa-state.service
    accounts-daemon.service
    atd.service
    crond.service
    dbus-:1.2-org.freedesktop.problems@0.service
    gssproxy.service
    rsyslog.service
    udisks2.service
   	chronyd.service
    smartd.service
    upower.service
)

# Mask Services
systemctl mask upower.service 2>/dev/null
systemctl mask avahi-daemon.service 2>/dev/null
systemctl mask auditd.service 2>/dev/null

if mmcli -L | grep -q "No modems were found"; then
    systemctl stop ModemManager.service
fi

for ((i=0; i<3; i++)); do
    any_active=false

    # Stop system services
    for svc in "${system_services[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            any_active=true
            systemctl stop "$svc" 2>/dev/null || true
        fi
    done

    [ "$any_active" = false ] && break
    sleep 1
done

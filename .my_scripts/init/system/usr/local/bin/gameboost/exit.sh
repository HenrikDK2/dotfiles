#!/bin/bash

# Set CPU governor to ondemand if available, else powersave
governor="powersave"
if grep -q "ondemand" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
    governor="ondemand"
fi

echo "$governor" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null

# Set AMD GPU to auto when not gaming
GPU=$(lspci | awk '/VGA|3D/{print "/sys/bus/pci/devices/0000:"$1}')

if [ -d "$GPU" ]; then
    [ -f "$GPU/power_dpm_force_performance_level" ] && echo "auto" > "$GPU/power_dpm_force_performance_level"
    [ -f "$GPU/power/control" ] && echo "auto" > "$GPU/power/control"
    [ -f "$GPU/pp_power_profile_mode" ] && echo "0" > "$GPU/pp_power_profile_mode"
fi

# Enable SELinux while playing games
setenforce 1

# Start system services
system_services=(
    systemd-journald.socket
    systemd-journald-dev-log.socket
    systemd-journald-audit.socket
    systemd-journald.service

    abrtd.service
    abrt-journal-core.service
    abrt-oops.service
    abrt-xorg.service

    auditd.service

	ModemManager.service
    accounts-daemon.service
    atd.service
    crond.service
    dbus-:1.2-org.freedesktop.problems@0.service
    gssproxy.service
    rsyslog.service
    udisks2.service
	cups.service
   	chronyd.service
    smartd.service
    upower.service
)

# Unmask Services
systemctl unmask upower.service 2>/dev/null
systemctl unmask avahi-daemon.service 2>/dev/null
systemctl unmask auditd.service 2>/dev/null

for ((i=0; i<2; i++)); do
    any_inactive=false

    # Start system services
    for svc in "${system_services[@]}"; do
        if ! systemctl is-active --quiet "$svc"; then
            any_inactive=true
            systemctl start "$svc" 2>/dev/null || true
        fi
    done

    [ "$any_inactive" = false ] && break
    sleep 1
done

# Kill lingering gamescope process
if ! pgrep -x "gamescope-wl" >/dev/null && pgrep -x "gamescopereaper" >/dev/null; then
    killall -9 gamescopereaper 2>/dev/null
fi

# Kill lingering winedevice.exe
[ "$(pgrep -fl '\.exe$' | wc -l)" -eq 1 ] && pgrep -x winedevice.exe >/dev/null && killall -9 winedevice.exe 2>/dev/null

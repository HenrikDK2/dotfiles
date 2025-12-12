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

# Start system services
system_services=(
	auditd.service

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

# Start user services
user_services=(
    gvfs-daemon
    gvfs-metadata
)

# Get all active user IDs with sessions
user_ids=($(loginctl list-sessions --no-legend | awk '{print $2}' | sort -u))

# Unmask upower / auditd
systemctl unmask upower.service auditd.service 2>/dev/null

for ((i=0; i<2; i++)); do
    any_inactive=false

    # Start system services
    for svc in "${system_services[@]}"; do
        if ! systemctl is-active --quiet "$svc"; then
            any_inactive=true
            systemctl start "$svc" 2>/dev/null || true
        fi
    done

    # Start user services for all active sessions
    for uid in "${user_ids[@]}"; do
        for svc in "${user_services[@]}"; do
            if ! systemctl --user --machine=${uid}@.host is-active --quiet "$svc" 2>/dev/null; then
                any_inactive=true
                systemctl --user --machine=${uid}@.host start "$svc" 2>/dev/null || true
            fi
        done
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

# Restore SATA link power management
for host in /sys/class/scsi_host/host*/link_power_management_policy; do
    echo med_power_with_dipm > "$host" 2>/dev/null
done

# Restore NVMe power state management (auto)
for nvme in /sys/block/nvme*/device/power_state; do
    echo -1 > "$nvme" 2>/dev/null  # -1 = auto/default
done

# Restore PCIe power management to auto
for pci in /sys/bus/pci/devices/*/power/control; do
    echo auto > "$pci" 2>/dev/null
done

# Restore PCIe ASPM to default
echo default > /sys/module/pcie_aspm/parameters/policy 2>/dev/null

# Reset PCIe ASPM to default (usually powersave or powersupersave)
echo default > /sys/module/pcie_aspm/parameters/policy 2>/dev/null

# Clear RAM
killall -q -9 chrome_crashpad 2>/dev/null
echo 3 > /proc/sys/vm/drop_caches

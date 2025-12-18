#!/bin/bash

function is_laptop() {
    if [ -d "/sys/class/power_supply/BAT0" ] || [ -d "/sys/class/power_supply/BAT1" ]; then
        return 0  # true: laptop
    else
        return 1  # false: desktop
    fi
}

function set_cpu_balanced() {
    local governor="powersave"
    if grep -q "ondemand" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
        governor="ondemand"
    fi
    echo "$governor" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
}

function set_amd_gpu_auto() {
    local GPU=$(lspci | awk '/VGA|3D/{print "/sys/bus/pci/devices/0000:"$1}')
    
    if [ -d "$GPU" ]; then
        [ -f "$GPU/power_dpm_force_performance_level" ] && echo "auto" > "$GPU/power_dpm_force_performance_level"
        [ -f "$GPU/power/control" ] && echo "auto" > "$GPU/power/control"
        [ -f "$GPU/pp_power_profile_mode" ] && echo "0" > "$GPU/pp_power_profile_mode"
    fi
}

function start_services() {
    local system_services=(
        auditd.service
        
        clamav-daemon.socket
        clamav-daemon
        clamav-freshclam
        
        libvirtd-admin.socket
        libvirtd-ro.socket
        libvirtd.socket
        libvirtd

        tlp
        cups
        avahi-daemon
        
        udisks2
        upower
        systemd-timesyncd
        docker
        containerd
    )
    
    local user_services=(
        gvfs-daemon
        gvfs-metadata
    )
    
    local user_ids=($(loginctl list-sessions --no-legend | awk '{print $2}' | sort -u))
    systemctl unmask upower.service auditd.service 2>/dev/null
    
    for ((i=0; i<2; i++)); do
        local any_inactive=false
        
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
}

function kill_lingering_processes() {
    if ! pgrep -x "gamescope-wl" >/dev/null && pgrep -x "gamescopereaper" >/dev/null; then
        killall -9 gamescopereaper 2>/dev/null
    fi
    
    [ "$(pgrep -fl '\.exe$' | wc -l)" -eq 1 ] && pgrep -x winedevice.exe >/dev/null && killall -9 winedevice.exe 2>/dev/null
}

function restore_sata_power_management() {
    for host in /sys/class/scsi_host/host*/link_power_management_policy; do
        echo med_power_with_dipm > "$host" 2>/dev/null
    done
}

function restore_nvme_power_management() {
    for nvme_dev in /sys/block/nvme*/device; do
        if [ -d "$nvme_dev/power" ]; then
            echo 1000 > "$nvme_dev/power/autosuspend_delay_ms" 2>/dev/null
            echo auto > "$nvme_dev/power/control" 2>/dev/null
        fi
    done
}

function restore_pcie_power_management() {
    for pci in /sys/bus/pci/devices/*/power/control; do
        echo auto > "$pci" 2>/dev/null
    done
    
    # Restore PCIe ASPM to default
    echo "default" > /sys/module/pcie_aspm/parameters/policy 2>/dev/null
}

function clear_ram_cache() {
    killall -q -9 chrome_crashpad 2>/dev/null
    echo 3 > /proc/sys/vm/drop_caches
}

function tlp_auto() {
    if systemctl is-active --quiet tlp.service && command -v tlp >/dev/null 2>&1; then
        tlp auto 2>/dev/null
    fi
}

function main() {
    set_cpu_balanced
    set_amd_gpu_auto
    start_services
    kill_lingering_processes
    
    if is_laptop; then
        tlp_auto
    else
        restore_sata_power_management
        restore_nvme_power_management
        restore_pcie_power_management
    fi
    
    clear_ram_cache
}

main "$@"

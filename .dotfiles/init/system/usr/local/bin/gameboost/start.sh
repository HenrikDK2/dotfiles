#!/bin/bash

function is_laptop() {
    if [ -d "/sys/class/power_supply/BAT0" ] || [ -d "/sys/class/power_supply/BAT1" ]; then
        return 0  # true: laptop
    else
        return 1  # false: desktop
    fi
}

function adjust_process_priorities() {
    for pid in "$@"; do
        renice -n -11 -p "$pid" >/dev/null 2>&1
        ionice -c 1 -n 0 -p "$pid" >/dev/null 2>&1
    done
}

function stop_services() {
    local system_services=(
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

        tlp
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

    systemctl mask upower.service auditd.service 2>/dev/null
    
    for ((i=0; i<3; i++)); do
        local any_active=false
        
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
}

function set_cpu_performance() {
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
}

function set_amd_gpu_performance() {
    local GPU=$(lspci | awk '/VGA|3D/{print "/sys/bus/pci/devices/0000:"$1}')
    
    # AMD GPU max performance
    if [ -d "$GPU" ]; then
        [ -f "$GPU/power_dpm_force_performance_level" ] && echo "manual" > "$GPU/power_dpm_force_performance_level"
        [ -f "$GPU/power/control" ] && echo "on" > "$GPU/power/control"
        [ -f "$GPU/pp_power_profile_mode" ] && echo "1" > "$GPU/pp_power_profile_mode"
    fi
}

function kill_background_processes() {
    local processes=(cmst mullvad-gui blueman-applet blueman-manager blueman-tray chrome_crashpad)
    
    for p in "${processes[@]}"; do
        pkill -9 "$p" 2>/dev/null
    done
}

function disable_sata_power_management() {
    for host in /sys/class/scsi_host/host*/link_power_management_policy; do
        echo max_performance > "$host" 2>/dev/null
    done
}

function disable_nvme_power_management() {
    for nvme_dev in /sys/block/nvme*/device; do
        if [ -d "$nvme_dev/power" ]; then
            echo -1 > "$nvme_dev/power/autosuspend_delay_ms" 2>/dev/null
            echo on > "$nvme_dev/power/control" 2>/dev/null
        fi
    done
}

function disable_pcie_power_management() {
    for pci in /sys/bus/pci/devices/*/power/control; do
        echo on > "$pci" 2>/dev/null
    done
    
    # Set PCIe ASPM to performance
    echo "performance" > /sys/module/pcie_aspm/parameters/policy 2>/dev/null
}

function clear_ram_cache() {
    pkill -9 chrome_crashpad
    echo 3 > /proc/sys/vm/drop_caches
}

function tlp_performance() {
	if systemctl is-active --quiet tlp.service && command -v tlp >/dev/null 2>&1; then
	    tlp ac 2>/dev/null
	fi
}

function main() {
    adjust_process_priorities "$@"
    
	if is_laptop; then
		tlp_performance
	else
	    disable_sata_power_management
	    disable_nvme_power_management
	    disable_pcie_power_management
	fi
    
    stop_services
    set_cpu_performance
    set_amd_gpu_performance
    kill_background_processes
    clear_ram_cache
}

main "$@"

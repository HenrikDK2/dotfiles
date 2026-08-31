#!/bin/bash

is_laptop() {
    [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]
}

has_active_docker_containers() {
    command -v docker >/dev/null 2>&1 &&
        systemctl is-active --quiet docker.service 2>/dev/null &&
        [ -n "$(docker ps -q 2>/dev/null)" ]
}

has_active_libvirt_domains() {
    command -v virsh >/dev/null 2>&1 &&
        systemctl is-active --quiet libvirtd.service 2>/dev/null &&
        [ -n "$(virsh list --state-running --name 2>/dev/null)" ]
}

stop_services() {
    local system_services=(
        smartd

        clamav-daemon
        clamav-freshclam

        cups
        avahi-daemon

        tlp
        upower

        systemd-timesyncd
        systemd-journald
        systemd-journald.socket
        systemd-journald-dev-log.socket
        systemd-journald-audit.socket
        systemd-journald-varlink.socket

        udisks2
    )

    local masked_services=(
        upower.service
        avahi-daemon.service
    )

    local user_services=(
        gvfs-daemon
        gvfs-metadata
        hypridle
    )

    has_active_docker_containers || system_services+=(docker containerd)
    has_active_libvirt_domains || system_services+=(libvirtd-admin libvirtd-ro libvirtd virtlogd)

    systemctl mask "${masked_services[@]}" 2>/dev/null
    systemctl stop "${system_services[@]}" 2>/dev/null

    local uid
    while read -r uid; do
        [ -n "$uid" ] && systemctl --user --machine="${uid}@.host" stop "${user_services[@]}" 2>/dev/null
    done < <(loginctl list-sessions --no-legend 2>/dev/null | awk '!seen[$2]++ {print $2}')
}

set_cpu_performance() {
    local gov
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > "$gov" 2>/dev/null
    done
}

set_amd_gpu_performance() {
    local gpu=$(lspci | awk '/VGA|3D/{print "/sys/bus/pci/devices/0000:" $1; exit}')

    [ -d "$gpu" ] || return
    [ -f "$gpu/power_dpm_force_performance_level" ] && echo manual > "$gpu/power_dpm_force_performance_level"
    [ -f "$gpu/power/control" ] && echo on > "$gpu/power/control"
    [ -f "$gpu/pp_power_profile_mode" ] && echo 1 > "$gpu/pp_power_profile_mode"
}

kill_background_processes() {
    pkill -9 -f '^(cmst|hypridle|mullvad-gui|blueman-applet|blueman-manager|blueman-tray|chrome_crashpad)( |$)' 2>/dev/null
}

disable_sata_power_management() {
    local host
    for host in /sys/class/scsi_host/host*/link_power_management_policy; do
        echo max_performance > "$host" 2>/dev/null
    done
}

disable_nvme_power_management() {
    local nvme_dev
    for nvme_dev in /sys/block/nvme*/device; do
        [ -d "$nvme_dev/power" ] || continue
        echo -1 > "$nvme_dev/power/autosuspend_delay_ms" 2>/dev/null
        echo on > "$nvme_dev/power/control" 2>/dev/null
    done
}

disable_pcie_power_management() {
    local pci
    for pci in /sys/bus/pci/devices/*/power/control; do
        echo on > "$pci" 2>/dev/null
    done
    echo performance > /sys/module/pcie_aspm/parameters/policy 2>/dev/null
}

clear_ram_cache() {
    pkill -9 -x chrome_crashpad 2>/dev/null
    echo 3 > /proc/sys/vm/drop_caches
}

tlp_performance() {
    command -v tlp >/dev/null 2>&1 &&
        systemctl is-active --quiet tlp.service &&
        tlp ac 2>/dev/null
}

set_process_priority() {
    local pid
    for pid; do
        renice -n -11 -p "$pid" >/dev/null 2>&1
        ionice -c2 -n0 -p "$pid" >/dev/null 2>&1
    done
}

main() {
    set_process_priority "$@"

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

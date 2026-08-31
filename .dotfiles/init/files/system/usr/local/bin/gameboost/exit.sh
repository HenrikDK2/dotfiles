#!/bin/bash

is_laptop() {
    [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]
}

set_cpu_balanced() {
    local governor=powersave
    grep -qw ondemand /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors && governor=ondemand
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$governor" > "$gov" 2>/dev/null
    done
}

set_amd_gpu_auto() {
    local gpu=$(lspci | awk '/VGA|3D/{print "/sys/bus/pci/devices/0000:" $1; exit}')

    [ -d "$gpu" ] || return
    [ -f "$gpu/power_dpm_force_performance_level" ] && echo auto > "$gpu/power_dpm_force_performance_level"
    [ -f "$gpu/power/control" ] && echo auto > "$gpu/power/control"
    [ -f "$gpu/pp_power_profile_mode" ] && echo 0 > "$gpu/pp_power_profile_mode"
}

start_services() {
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
        docker
        containerd
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

    local user_ids uid
    mapfile -t user_ids < <(loginctl list-sessions --no-legend 2>/dev/null | awk '!seen[$2]++ {print $2}')

    systemctl unmask "${masked_services[@]}" 2>/dev/null
    systemctl start "${system_services[@]}" 2>/dev/null

    for uid in "${user_ids[@]}"; do
        systemctl --user --machine="${uid}@.host" start "${user_services[@]}" 2>/dev/null
    done
}

kill_lingering_processes() {
    ! pgrep -x gamescope-wl >/dev/null && pgrep -x gamescopereaper >/dev/null &&
        killall -9 gamescopereaper 2>/dev/null

    [ "$(pgrep -fc '\.exe$')" -eq 1 ] && pgrep -x winedevice.exe >/dev/null &&
        killall -9 winedevice.exe 2>/dev/null
}

restore_sata_power_management() {
    local host
    for host in /sys/class/scsi_host/host*/link_power_management_policy; do
        echo med_power_with_dipm > "$host" 2>/dev/null
    done
}

restore_nvme_power_management() {
    local nvme_dev
    for nvme_dev in /sys/block/nvme*/device; do
        [ -d "$nvme_dev/power" ] || continue
        echo 1000 > "$nvme_dev/power/autosuspend_delay_ms" 2>/dev/null
        echo auto > "$nvme_dev/power/control" 2>/dev/null
    done
}

restore_pcie_power_management() {
    local pci
    for pci in /sys/bus/pci/devices/*/power/control; do
        echo auto > "$pci" 2>/dev/null
    done
    echo default > /sys/module/pcie_aspm/parameters/policy 2>/dev/null
}

clear_ram_cache() {
    killall -q -9 chrome_crashpad 2>/dev/null
    echo 3 > /proc/sys/vm/drop_caches
}

tlp_auto() {
    command -v tlp >/dev/null 2>&1 && systemctl is-active --quiet tlp.service &&
        tlp auto 2>/dev/null
}

main() {
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

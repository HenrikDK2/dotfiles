#!/usr/bin/env bash
# Stops and masks all active user-level systemd services containing "kdeconnect".
# Also conditionally enables/disables ntfs-nag, obex, and mpris-proxy based on hardware.
set -euo pipefail
sleep 10

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
mask_service() {
    local svc="$1"
    local reason="$2"
    local state
    state=$(systemctl --user is-enabled "$svc" 2>/dev/null || true)
    if [[ "$state" == "masked" ]]; then
        echo "    Already masked: $svc"
    else
        systemctl --user stop "$svc" 2>/dev/null || true
        systemctl --user mask "$svc" && echo "    Masked ($reason): $svc"
    fi
}

unmask_and_start_service() {
    local svc="$1"
    local reason="$2"
    local state
    state=$(systemctl --user is-enabled "$svc" 2>/dev/null || true)
    if [[ "$state" == "masked" ]]; then
        systemctl --user unmask "$svc" && echo "    Unmasked ($reason): $svc"
    else
        echo "    Not masked, skipping unmask: $svc"
    fi
    if systemctl --user is-active "$svc" &>/dev/null; then
        echo "    Already running: $svc"
    else
        systemctl --user start "$svc" && echo "    Started ($reason): $svc"
    fi
}

# ---------------------------------------------------------------------------
# Geoclue Demo Agent: unconditionally disable
# ---------------------------------------------------------------------------
echo "==> Disabling Geoclue Demo Agent..."
# Match the escaped unit name as systemd sees it
GEOCLUE_SVC=$(systemctl --user list-units --type=service --no-legend --no-pager 2>/dev/null \
    | awk '{print $1}' \
    | grep -i "geoclue" || true)
if [[ -n "$GEOCLUE_SVC" ]]; then
    while IFS= read -r svc; do
        mask_service "$svc" "demo agent not needed"
    done <<< "$GEOCLUE_SVC"
else
    echo "    No Geoclue services found."
fi

echo ""

# ---------------------------------------------------------------------------
# NTFS-nag: toggle based on NTFS/exFAT partition presence
# ---------------------------------------------------------------------------
echo "==> Checking for NTFS/exFAT partitions..."
if lsblk -o FSTYPE 2>/dev/null | grep -qiE 'ntfs|exfat'; then
    echo "    NTFS/exFAT partition detected."
    unmask_and_start_service "ntfs-nag.service" "NTFS/exFAT present"
else
    echo "    No NTFS/exFAT partitions found."
    mask_service "ntfs-nag.service" "no NTFS/exFAT"
fi

echo ""

# ---------------------------------------------------------------------------
# Bluetooth services: toggle obex + mpris-proxy based on BT hardware
# ---------------------------------------------------------------------------
echo "==> Checking for Bluetooth hardware..."
BT_FOUND=false
if command -v rfkill &>/dev/null && rfkill list bluetooth 2>/dev/null | grep -q "Bluetooth"; then
    BT_FOUND=true
elif [[ -d /sys/class/bluetooth ]] && compgen -G "/sys/class/bluetooth/hci*" &>/dev/null; then
    BT_FOUND=true
fi

if $BT_FOUND; then
    echo "    Bluetooth device detected."
    unmask_and_start_service "obex.service"        "Bluetooth present"
    unmask_and_start_service "mpris-proxy.service" "Bluetooth present"
else
    echo "    No Bluetooth hardware found."
    mask_service "obex.service"        "no Bluetooth"
    mask_service "mpris-proxy.service" "no Bluetooth"
fi

echo ""

# ---------------------------------------------------------------------------
# KDE Connect: stop and mask all active user services
# ---------------------------------------------------------------------------
echo "==> Checking for active KDE Connect user services..."
ACTIVE_SERVICES=$(systemctl --user list-units --type=service --state=active --no-legend --no-pager 2>/dev/null \
    | awk '{print $1}' \
    | grep -i "kdeconnect" || true)

if [[ -z "$ACTIVE_SERVICES" ]]; then
    echo "    No active KDE Connect services found."
else
    while IFS= read -r svc; do
        systemctl --user stop "$svc" && echo "    Stopped: $svc"
        systemctl --user mask "$svc" && echo "    Masked:  $svc"
    done <<< "$ACTIVE_SERVICES"
fi

echo ""

# ---------------------------------------------------------------------------
# KDE Connect: kill any remaining processes
# ---------------------------------------------------------------------------
echo "==> Killing any remaining KDE Connect processes..."
PROCS=(kdeconnectd kdeconnect-indicator kdeconnect-handler)
for proc in "${PROCS[@]}"; do
    if pgrep -x "$proc" > /dev/null 2>&1; then
        echo "    Killing: $proc (PID(s): $(pgrep -x "$proc" | tr '\n' ' '))"
        pkill -x "$proc"
    else
        echo "    Not running: $proc"
    fi
done

echo ""
echo "==> Done."

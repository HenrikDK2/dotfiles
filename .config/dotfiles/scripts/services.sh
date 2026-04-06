#!/usr/bin/env bash
echo "Disabling and masking selected services..."

SYSTEM_SERVICES=(
    systemd-oomd.service
)

USER_SERVICES=(
    kde-baloo.service
    plasma-baloorunner.service
    kdeconnect.service
    dbus-org.kde.kdeconnect.service
    io.github.kolunmi.Bazaar.service
)

mask_service() {
    local scope="$1"
    local svc="$2"
    local -a ctl=(systemctl "$scope")

    if "${ctl[@]}" is-active "$svc" &>/dev/null; then
        "${ctl[@]}" stop "$svc" || true
    fi

    if ! ("${ctl[@]}" is-enabled "$svc" 2>&1 | grep -q "masked"); then
        "${ctl[@]}" disable "$svc" 2>/dev/null || true
        "${ctl[@]}" mask "$svc" 2>/dev/null || true
    fi
}

for svc in "${SYSTEM_SERVICES[@]}"; do
    mask_service "--system" "$svc"
done

for svc in "${USER_SERVICES[@]}"; do
    mask_service "--user" "$svc"
done

# Baloo CLI cleanup
if command -v balooctl >/dev/null 2>&1; then
    balooctl disable || true
    balooctl purge || true
fi

if command -v balooctl6 >/dev/null 2>&1; then
    balooctl6 disable || true
    balooctl6 purge || true
fi

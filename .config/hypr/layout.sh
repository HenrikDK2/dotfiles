#!/bin/bash

WAYBAR_CFG_DEFAULT="$HOME/.config/waybar/config"

ultrawide() {
    hyprctl keyword general:layout master >/dev/null
    hyprctl keyword general:gaps_out 0 >/dev/null
    setsid waybar -c "$WAYBAR_CFG_DEFAULT" >/dev/null 2>&1 &
}

default() {
    local WAYBAR_TMP_CFG
    WAYBAR_TMP_CFG="$(mktemp /tmp/waybar-config.XXXXXX.json)"

    jq '.exclusive = true' "$WAYBAR_CFG_DEFAULT" > "$WAYBAR_TMP_CFG"

    hyprctl keyword general:layout dwindle >/dev/null
    hyprctl keyword general:gaps_out 20 >/dev/null

    pkill -x waybar 2>/dev/null
    setsid waybar -c "$WAYBAR_TMP_CFG" >/dev/null 2>&1 &
}

dynamic_layout() {
    local dims width height

    dims=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0] | "\(.width) \(.height)"')
    read -r width height <<<"$dims"

    pkill -x waybar 2>/dev/null

    # ultrawide first
    if (( width * 10 > height * 25 )); then
        ultrawide
    else
        default
    fi
}

dynamic_layout

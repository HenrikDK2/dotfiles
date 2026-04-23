#!/bin/bash

dynamic_layout() {
    local dims=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0] | "\(.width) \(.height)"')
    read -r width height <<<"$dims"

    if (( width * 10 > height * 25 )); then
        pkill -x waybar 2>/dev/null
        hyprctl keyword general:layout master >/dev/null
        hyprctl keyword general:gaps_out 0 >/dev/null
        WAYBAR_CONFIG="$WAYBAR_CFG_DEFAULT"
    else
        pkill -x waybar 2>/dev/null
        hyprctl keyword general:layout dwindle >/dev/null
        hyprctl keyword general:gaps_out 20 >/dev/null
        WAYBAR_CONFIG="$WAYBAR_CFG_EXCLUSIVE"
    fi
    
    setsid waybar  >/dev/null 2>&1 &
}

dynamic_layout


#!/bin/bash

# Set lowest CPU & I/O priority
renice 19 -p $$ >/dev/null 2>&1
ionice -c 3 -p $$ >/dev/null 2>&1

#################
### VARIABLES ###
#################

WAYBAR_CFG_DEFAULT="$HOME/.config/waybar/config"
WAYBAR_CFG_EXCLUSIVE="$HOME/.config/waybar/config_exclusive"
SCRIPT_DIR="$HOME/.dotfiles/login.d"

WAYBAR_PID=0
last_toggle_scripts_time=0

#################
### FUNCTIONS ###
#################

# Cache hyprctl output to avoid multiple calls
update_hypr_variables() {
    local hypr_clients_json="$(hyprctl clients -j 2>/dev/null)" || hypr_clients_json="[]"
    local active_workspace_json="$(hyprctl activeworkspace -j 2>/dev/null)" || active_workspace_json='{"id":0}'
    
    active_workspace_id=$(jq -r '.id' <<<"$active_workspace_json")
    fullscreen_window_count=$(jq "[.[] | select(.workspace.id == $active_workspace_id and .fullscreen == 2)] | length" <<<"$hypr_clients_json")
    non_floating_window_count=$(jq "[.[] | select(.workspace.id == $active_workspace_id and .floating == false)] | length" <<<"$hypr_clients_json")
}

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
}

secret_firefox_instance() {
	if ! pgrep -x firefox >/dev/null; then
		hyprctl dispatch exec "[workspace special silent] firejail /usr/bin/firefox"
	fi
}

toggle_waybar() {
    if (( fullscreen_window_count >= 1 )); then
        pkill -x waybar 2>/dev/null
        WAYBAR_PID=0
    else
        if ! pgrep -x waybar >/dev/null; then
            waybar -c "${WAYBAR_CONFIG:-$WAYBAR_CFG_DEFAULT}" >/dev/null 2>&1 &
            WAYBAR_PID=$!
        fi
    fi
}

toggle_scripts() {
    local now=$(date +%s)

    (( now - last_toggle_scripts_time < 2 )) && return
    last_toggle_scripts_time=$now

    if (( fullscreen_window_count >= 1 )); then
        pkill -f random_wallpaper.sh 2>/dev/null
    else
        pgrep -f random_wallpaper.sh >/dev/null || "$SCRIPT_DIR/random_wallpaper.sh" &
    fi
}

######################
### EVENT HANDLERS ###
######################

handle_event() {
    case $1 in
        openwindow*|closewindow*|movewindow*|workspace*|fullscreen*)
            update_hypr_variables
            case $1 in
                openwindow*|workspace*|fullscreen*)
                    toggle_waybar &
                    toggle_scripts &
                    ;;
                closewindow*)
                    toggle_waybar &
                    secret_firefox_instance &
                    ;;
                movewindow*)
                    toggle_scripts &
                    ;;
            esac
            ;;
    esac

    case $1 in
        monitor*|configreloaded*)
        	dynamic_layout
        	update_hypr_variables 
        	toggle_waybar
    esac
}

#################
### MAIN LOOP ###
#################

dynamic_layout
update_hypr_variables
secret_firefox_instance
toggle_waybar

socat -U -s - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | \
while IFS= read -r line; do
    handle_event "$line"
done

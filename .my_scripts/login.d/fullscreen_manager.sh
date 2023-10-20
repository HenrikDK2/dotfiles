#!/bin/bash

renice 20 $$
ionice -c 3 -p $$

swaymsg -t subscribe -m '[ "window" ]' | while read -r window_json; do
    window_event=$(jq -r '.change' <<< "$window_json")

    if [[ $window_event = @(focus|fullscreen_mode|close) ]]; then
        window_fullscreen_status=$(jq -r '.container.fullscreen_mode' <<< "$window_json")

        if [[ $window_fullscreen_status = "1" ]]; then
        	killall -9 waybar
        else
        	if ! pgrep -x "waybar" > /dev/null; then
            	waybar &
            fi
        fi
    fi
done

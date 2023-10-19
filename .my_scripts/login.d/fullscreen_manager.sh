#!/bin/bash

renice 20 $$
ionice -c 3 -p $$

swaymsg -t subscribe -m '[ "window" ]' | while read window_json; do
    window_event=$(echo ${window_json} | jq -r '.change')

    # Process only focus, close,  and fullscreen events
    if [[ $window_event = "focus" || $window_event = "fullscreen_mode" || $window_event = "close" ]]; then
        window_fullscreen_status=$(echo ${window_json} | jq -r '.container.fullscreen_mode')

        if [[ $window_fullscreen_status = "1" ]]; then
            killall -9 waybar swaybg;
        elif [[ $window_fullscreen_status = "0" ]]; then
        	if ! pgrep -x "waybar" > /dev/null; then
            	waybar &
            	
            fi

            if ! pgrep -x "swaybg" > /dev/null; then
				swaybg -i $WALLPAPER -m $WALLPAPER_MODE &
            fi
        fi
    fi
done

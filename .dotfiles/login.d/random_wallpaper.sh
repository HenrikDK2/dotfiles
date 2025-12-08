#!/bin/bash

if pgrep -x "sway" >/dev/null || pgrep -x "hyprland" >/dev/null; then

	# Set lowest CPU & I/O priority
	nice -n 19 -p $$ >/dev/null 2>&1
	ionice -c 3 -n 7 -p $$ >/dev/null 2>&1

	set_wallpapers(){
		wallpapers=("$HOME/Wallpapers"/*)
	    wallpapers=($(shuf -e "${wallpapers[@]}"))
	    
	    # Remove XCF files from the array
	    for ((i = 0; i < ${#wallpapers[@]}; i++)); do
	        [[ ${wallpapers[i]} == *.xcf ]] && unset -v 'wallpapers[i]'
	    done

		# If swaybg is running, filter out current wallpaper
		if pgrep -x swaybg; then
			current_wallpaper=$(pgrep -a swaybg | grep -oP '(?<=-i )[^ ]+')

			for ((i = 0; i < ${#wallpapers[@]}; i++)); do
			    [[ "${wallpapers[i]}" == "$current_wallpaper" ]] && unset -v 'wallpapers[i]'
			done
		fi
	}

	# Layout script from "$HOME/.config/hypr/layout.sh", kills this process when fullscreen mode is enabled
	# To stop the wallpaper from switching on fullscreen exit, delay the process.
	if pgrep -x swaybg; then
		sleep 5m
	fi

	# Main loop
	while true; do
	    for wallpaper in "${wallpapers[@]}"; do
	        pids=$(pgrep -d' ' swaybg)
	        swaybg -i $wallpaper -m center &
	        sleep 2s
	    	kill $pids
	        sleep 20m
	    done
		
	   	set_wallpapers
	done
fi

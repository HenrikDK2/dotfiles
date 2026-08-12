#!/bin/bash

if pgrep -x "sway" >/dev/null || pgrep -x "hyprland" >/dev/null || pgrep -x "start-hyprland"; then
	# Set lowest CPU & I/O priority
	nice -n 19 -p $$ >/dev/null 2>&1
	ionice -c 3 -n 7 -p $$ >/dev/null 2>&1

	# Custom fork-free sleep function
	exec {TIMER_FD}<> <(:)
	wait_for() {
	    local seconds=$1
	    read -r -t "$seconds" -u "$TIMER_FD" _
	}

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

	# Main loop
	while true; do
	    for wallpaper in "${wallpapers[@]}"; do
	        pids=$(pgrep -d' ' swaybg)
	        swaybg -i $wallpaper -m center &
	        wait_for 2
	    	kill $pids
	        wait_for 1200 # 20 mins
	    done
		
	   	set_wallpapers
	done
fi

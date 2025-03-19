#!/bin/bash

# Reduce priority of script
renice -n 20 -p $$ -g $$
ionice -c 3 -P $$

set_wallpapers(){
	wallpapers=("$HOME/Wallpapers"/*)
    wallpapers=($(shuf -e "${wallpapers[@]}"))
    
    # Remove XCF files from the array
    for ((i = 0; i < ${#wallpapers[@]}; i++)); do
        [[ ${wallpapers[i]} == *.xcf ]] && unset -v 'wallpapers[i]'
    done
}

while true; do
    for wallpaper in "${wallpapers[@]}"; do
        pids=$(pgrep -d' ' swaybg)
        swaybg -i $wallpaper -m center &
        sleep 5s
    	kill $pids
        sleep 20m
    done
	
   	set_wallpapers
done

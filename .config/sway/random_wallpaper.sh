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

if ! pgrep swww-daemon >/dev/null; then
    swww-daemon &
	set_wallpapers
    swww img -t 'none' ${wallpapers[0]}
    wallpapers=("${wallpapers[@]:1}")
    sleep 10m
fi

while true; do
    for wallpaper in "${wallpapers[@]}"; do
        swww img -t outer --transition-step 90 --transition-pos 'top-right' "$wallpaper"
        sleep 10m
    done
	
   	set_wallpapers
done

#!/bin/bash

is_start_script_started=false
pids=""

# Define paths for native Linux games
readonly native_paths="\
/usr/games|\
/usr/local/games|\
~/Games|\
~/.local/share/Steam|\
~/.steam|\
/usr/share/games|\
~/.local/share/lutris|\
~/.local/share/vulkan|\
~/.config/itch|\
~/.local/share/gogdownloader|\
/opt/games|\
/opt/gog|\
~/.local/share/Paradox Interactive|\
~/.local/share/games"

# Define known game-related processes
readonly game_processes="proton|gamescope|minecraft|Wine-GE|shadps4|steam_app|lutris-wrapper|runner|mangohud"

# Define graphics API related patterns
readonly graphics_patterns="\
vulkan|\
vkd3d|\
dxvk|\
d3d|\
glx|\
opengl|\
libGL|\
nouveau|\
mesa|\
wayland-egl|\
libdrm|\
libvulkan|\
swrast|\
vkBasalt|\
shadercache|\
nvapi|\
egl|\
directx|\
SDL|\
sdl-game"

# Combine patterns
readonly combined_pattern="($game_processes|$native_paths|$graphics_patterns)"

# For debug purposes, I want to check for false positives
debug_pattern_match() {
	declare -A pattern_matches
	
	for pid in $1; do
	    local cmd=$(ps -p "$pid" -o cmd=)
	    local match=$(echo "$cmd" | grep -oE "$combined_pattern" | head -1)
	    if [[ -n $match ]]; then
	        pattern_matches["$match"]+="$pid "
	    fi
	done
	
	# Dump all matches
	for match in "${!pattern_matches[@]}"; do
	    echo "Info: Matched Pattern: '$match' | Process IDs: ${pattern_matches[$match]}"
	done
}

# Function to set pids variable, and check if any game-related processes are running
is_game_running() {
    pids=$(pgrep -fi "$combined_pattern") && return 0 || return 1
}

# Main loop
while true; do
    if is_game_running; then
        if ! $is_start_script_started; then
            echo "GameBoost - Switching to performance mode"
            ./usr/local/bin/gameboost/start.sh "$pids" >/dev/null 2>&1 &
            debug_pattern_match "$pids"
            is_start_script_started=true
        fi
    elif $is_start_script_started; then
        echo "GameBoost - Switching to power-saving mode"
        ./usr/local/bin/gameboost/exit.sh >/dev/null 2>&1 &
        is_start_script_started=false
    fi
    
    sleep 30
done

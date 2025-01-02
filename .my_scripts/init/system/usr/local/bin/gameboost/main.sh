#!/bin/bash
is_start_script_started=false

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
readonly game_processes="proton|gamescope|minecraft|Wine-GE|shadps4|\.exe|steam_app|lutris-wrapper|runner|mangohud"

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
wine-preloader|\
shadercache|\
nvapi|\
egl|\
directx|\
SDL|\
sdl-game"

# Combine patterns
readonly combined_pattern="($game_processes|$native_paths|$graphics_patterns)"

# Function to check if any game-related processes are running
is_game_running() {
    if pids=$(pgrep -fi "$combined_pattern"); then
        renice -n -19 -p $pids >/dev/null 2>&1

        # For debug purposses, I want to check for false positives
        for pid in $pids; do
            local cmd=$(ps -p "$pid" -o cmd=)
            local match=$(echo "$cmd" | grep -oE "$combined_pattern" | head -1)
            echo "Info: Process ID: $pid | Matched Pattern: $match"
        done
    
        return 0
    fi
    
    return 1
}

# Main loop
while true; do
    if is_game_running; then
        if ! $is_start_script_started; then
            echo "GameBoost - Switching to performance mode"
            ./usr/local/bin/gameboost/start.sh >/dev/null 2>&1 &
            is_start_script_started=true
        fi
    elif $is_start_script_started; then
        echo "GameBoost - Switching to power-saving mode"
        ./usr/local/bin/gameboost/exit.sh >/dev/null 2>&1 &
        is_start_script_started=false
    fi
    
    sleep 30
done

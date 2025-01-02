#!/bin/bash

is_start_script_started=false

# Define paths for native Linux games
readonly native_paths="\
/usr/games|\
/usr/local/games|\
~/Games|\
~/.local/share/Steam|\
~/.steam|\y
/usr/share/games|\
~/.local/share/lutris|\
~/.local/share/flatpak/app/|\
/var/lib/flatpak/app/|\
~/.var/app/|\
~/.local/share/vulkan|\
~/.config/itch|\
~/.local/share/gogdownloader|\
/opt/games|\
/opt/gog|\
~/.local/share/Paradox Interactive|\
~/.local/share/games"

# Define known game-related processes
readonly game_processes="proton|gamescope|minecraft|Wine-GE|shadps4|\.exe|steam_app|steam-runtime|lutris-wrapper|runner|mangohud"

# Combine native_paths & game_processes to a combined pattern
readonly combined_pattern="($game_processes|$native_paths)"

# Function to check if any game-related processes are running
is_game_running() {
	if pids=$(pgrep -f "$combined_pattern"); then
        renice -n -19 -p $pids >/dev/null 2>&1
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

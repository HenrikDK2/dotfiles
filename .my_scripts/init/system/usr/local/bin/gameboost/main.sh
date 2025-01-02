#!/bin/bash

total_mem=$(free -m | awk '/^Mem:/ {print $2}')
min_ram_limit=$((total_mem / 2 < 2000 ? total_mem / 2 : 2000)) # Whichever is lower 2GB or 50% of ram
is_start_script_started=false

# Function to check if any game-related processes are running
is_game_running() {
    if pids=$(pgrep -f "(proton|gamescope|minecraft|Wine-GE|shadps4)"); then
        renice -n -19 -p $pids >/dev/null 2>&1
        
        # Since Proton, Gamescope or Wine-GE is running, then we know it's a game
        # So find and adjust priority of all running .exe processes
        if exe_pids=$(pgrep -f "\.exe"); then
            renice -n -11 -p $exe_pids >/dev/null 2>&1
        fi

        return 0
    fi

    return 1
}

is_gpu_usage_above_30() {
    usage=$( [[ -f /sys/class/drm/card0/device/gpu_busy_percent ]] && cat /sys/class/drm/card0/device/gpu_busy_percent || nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1 )
    [[ $usage -gt 30 ]]
}

# Check gpu and system memory activity to determine if a game is running
check_game_activity() {
    is_gpu_usage_above_30 || return 1

    if pid=$(ps --no-headers -eo pid,rss | awk -v limit=$((min_ram_limit*1024)) '$2 > limit {print $1; exit}'); then
        renice -n -11 -p "$pid" >/dev/null 2>&1
        return 0
    fi

    return 1
}

# Main loop
while true; do
    if is_game_running || check_game_activity; then
        if [ "$is_start_script_started" = false ]; then
            echo "GameBoost - Switching to performance mode"
            ./usr/local/bin/gameboost/start.sh >/dev/null 2>&1 &
            is_start_script_started=true
        fi
    elif [ "$is_start_script_started" = true ]; then
        echo "GameBoost - Switching to power-saving mode"
		./usr/local/bin/gameboost/exit.sh >/dev/null 2>&1 &
        is_start_script_started=false
    fi

    sleep 30
done

#!/bin/bash

total_mem=$(free -m | awk '/^Mem:/ {print $2}') # Get total system memory in MB
threshold_mem=$((total_mem / 2)) # 50% of total memory
min_ram_limit=$((threshold_mem < 2000 ? threshold_mem : 2000)) # Whichever is lower 2GB or 50% of ram

# Function to check if any game-related processes are running
is_game_running() {
	if pgrep -f "(proton|gamescope)" > /dev/null; then
		return 0
	else
		return 1
	fi
}

is_gpu_usage_above_50() {
    local usage=0

    if lspci | grep -i "AMD/ATI" >/dev/null; then
        # AMD GPU: Use gpu_busy_percent
        if [[ -f /sys/class/drm/card0/device/gpu_busy_percent ]]; then
            usage=$(cat /sys/class/drm/card0/device/gpu_busy_percent)
        fi
    elif lspci | grep -i "Intel" >/dev/null; then
        # Intel GPU: Use gpu_busy_percent
        if [[ -f /sys/class/drm/card0/device/gpu_busy_percent ]]; then
            usage=$(cat /sys/class/drm/card0/device/gpu_busy_percent)
        fi
    elif lspci | grep -i "NVIDIA" >/dev/null; then
        # NVIDIA GPU: Use nvidia-smi
        if command -v nvidia-smi >/dev/null; then
            usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1)
        fi
    fi

    # Check if GPU usage is above 50%
    if [[ $usage -gt 50 ]]; then
        return 0
    else
        return 1
    fi
}

# Check gpu and system memory activity to determine if a game is running
check_game_activity() {
	if ! is_gpu_usage_above_50; then
		return 1
	fi

    # Check the top 5 processes by memory usage and compare with min_ram_limit
    if ps aux --sort=-%mem | awk 'NR>1 {if ($6/1024 > '$min_ram_limit') exit 0} END {exit 1}'; then
        return 0  # Return 0 if a process is using more than min_ram_limit
    else
        return 1  # Return 1 if no process exceeds the min_ram_limit
    fi
}

# Combine multiple checks to determine if a game is running
is_game_detected() {
	if is_game_running || check_game_activity; then
		return 0
	else
		return 1
	fi
}

# Main loop
IS_START_SCRIPT_STARTED=false

while true; do
    if is_game_detected; then
        GAME_DETECTED=true
   	else 
		GAME_DETECTED=false
   	fi

    if [ "$GAME_DETECTED" == "true" ] && [ "$IS_START_SCRIPT_STARTED" == "false" ]; then
        echo "Game is detected - Switching to performance mode"
   		(./usr/local/bin/gameboost/start.sh >/dev/null 2>&1 &)
        IS_START_SCRIPT_STARTED=true
    elif [ "$GAME_DETECTED" == "false" ] && [ "$IS_START_SCRIPT_STARTED" == "true" ]; then
        echo "Game is no longer detected - Reverting back"
        (./usr/local/bin/gameboost/exit.sh >/dev/null 2>&1 &)
        IS_START_SCRIPT_STARTED=false
    fi

    sleep 30
done

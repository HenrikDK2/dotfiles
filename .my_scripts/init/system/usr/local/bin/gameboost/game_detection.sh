#!/bin/bash

total_mem=$(free -m | awk '/^Mem:/ {print $2}') # Get total system memory in MB
threshold_mem=$((total_mem / 2)) # 50% of total memory
min_ram_limit=$((threshold_mem < 2000 ? threshold_mem : 2000))

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

# Check system memory and determine if game-related activity is present
check_game_activity() {
    local detected=1  # Default to "no game activity"

    # Loop through the top processes and check conditions
    while read -r pid name ram_mb; do
        if is_gpu_usage_above_50; then
            detected=0  # Set to "game activity detected"
            break       # Exit the loop
        fi
    done < <(ps -eo pid,comm,%mem --sort=-%mem | head -n 10 | awk -v limit=$min_ram_limit -v total_mem=$total_mem '
        NR > 1 {
            ram_mb = ($3 / 100) * total_mem;  # Convert %mem to MB
            if (ram_mb > limit) {
                print $1, $2, ram_mb
            }
        }')

    return $detected
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

#!/bin/bash

total_mem=$(free -m | awk '/^Mem:/ {print $2}') # Get total system memory in MB
threshold_mem=$((total_mem / 2)) # 50% of total memory
min_ram_limit=$((threshold_mem < 2000 ? threshold_mem : 2000)) # Whichever is lower 2GB or 50% of ram

gpu_info=$(lspci | grep -iE "AMD/ATI|Intel|NVIDIA")

is_start_script_started=false

# Function to check if any game-related processes are running
is_game_running() {
    pids=$(pgrep -f "(proton|gamescope|minecraft)")

    if [ -n "$pids" ]; then
        # Change niceness of all matching processes to -19
		renice -n -19 -p $pids >/dev/null 2>&1
        return 0  # Return 0 if any game-related process is found
    else
        return 1  # Return 1 if no game-related processes are found
    fi
}

is_gpu_usage_above_50() {
    local usage=0
    
	if [[ "$gpu_info" =~ NVIDIA ]]; then
	    # NVIDIA GPU: Use nvidia-smi
	    command -v nvidia-smi >/dev/null && usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1)
	else
	    # AMD/Intel GPU: Use gpu_busy_percent
	    [[ -f /sys/class/drm/card0/device/gpu_busy_percent ]] && usage=$(< /sys/class/drm/card0/device/gpu_busy_percent)
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

    pid=$(ps aux --sort=-%mem | awk 'NR>1 {if ($6/1024 > '$min_ram_limit') {print $2; exit}}')
    
    if pid; then
    	sudo renice -n -19 -p "$pid"
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
while true; do
    if is_game_detected; then
        is_game_running=true
   	else 
		is_game_running=false
   	fi

    if [ "$is_game_running" == "true" ] && [ "$is_start_script_started" == "false" ]; then
        echo "Game is detected - Switching to performance mode"
   		(./usr/local/bin/gameboost/start.sh >/dev/null 2>&1 &)
        is_start_script_started=true
    elif [ "$is_game_running" == "false" ] && [ "$is_start_script_started" == "true" ]; then
        echo "Game is no longer detected - Reverting back"
        (./usr/local/bin/gameboost/exit.sh >/dev/null 2>&1 &)
        is_start_script_started=false
    fi

    sleep 30
done

#!/bin/bash

is_start_script_started=false
pids=""

# Define filesystem paths
readonly fs_paths="\
.local/share/Steam/steamapps/common/*|\
/Games/*|\
.local/share/Paradox Interactive/*|\
/compatibilitytools.d/*"

# Define known game-related processes
readonly game_processes="gamescope|minecraft|shadps4|mangohud|vkBasalt|SteamLaunch AppId="

# Combine patterns
readonly combined_pattern="($game_processes|$fs_paths)"

# Function to set pids variable, and check if any game-related processes are running
is_game_running() {
    pids=$(pgrep -fi "$combined_pattern") && return 0 || return 1
}

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

send_notification() {
	uid=$(loginctl list-sessions | awk 'NR==2 {print $2}')
	echo "GameBoost - $1"
	runuser -u $(id -nu $uid) -- notify-send "GameBoost" "$1"
}

# Main loop
while true; do
    if is_game_running; then
        if ! $is_start_script_started; then
            send_notification "Switching to performance mode"
            ./usr/local/bin/gameboost/start.sh "$pids" >/dev/null 2>&1 &
            debug_pattern_match "$pids"
            is_start_script_started=true
        fi
    elif $is_start_script_started; then
        send_notification "Switching to power-saving mode"
        killall start.sh
        ./usr/local/bin/gameboost/exit.sh >/dev/null 2>&1 &
        is_start_script_started=false
    fi
    
    sleep 30
done

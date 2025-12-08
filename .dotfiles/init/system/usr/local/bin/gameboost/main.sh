#!/bin/bash

readonly GAMEBOOST_FLAG="/tmp/gameboost-running.flag"
readonly LOG_FILE="/tmp/gameboost.log"
CURRENT_PID=""

readonly GAME_PATTERNS=(
    ".*/proton waitforexitandrun"
    "minecraft.+\.jar"
    "/Games/.+\.(AppImage|x86_64|i386)$"
    "/steamapps/common/.+\.(AppImage|x86_64|i386)"
)

readonly EXCLUDED_PATTERNS=(
    "wineserver"
    "pressure-vessel/bin/pressure-vessel-wrap"
    "pressure-vessel/libexec/steam-runtime-tools-0/srt-bwrap"
    "/windows/system32/.*"
    "(yay|pacman|pgrep|find|xargs|grep|awk|rsync|tar|cat)[[:space:]]"
)

# Build optimized regex patterns from arrays (done once at startup)
build_pattern() {
    local IFS='|'
    local combined=()
    
    for p in "$@"; do
        combined+=("$p")
    done

    echo "${combined[*]}"
}

readonly GAME_PATTERN=$(build_pattern "${GAME_PATTERNS[@]}")
readonly EXCLUDED_PATTERN=$(build_pattern "${EXCLUDED_PATTERNS[@]}")

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

notify_user() {
    local session=$(loginctl list-sessions --no-legend | while read id user seat; do
        [[ $(loginctl show-session "$id" -p Active --value) == "yes" ]] || continue
        [[ $(loginctl show-session "$id" -p Type --value) =~ ^(x11|wayland)$ ]] || continue
        echo "$id"
        break
    done)
    
    [[ -z "$session" ]] && return
    
    local user=$(loginctl show-session "$session" -p Name --value)
    local uid=$(id -u "$user")
    local dbus="unix:path=/run/user/$uid/bus"
    
    sudo -u "$user" DBUS_SESSION_BUS_ADDRESS="$dbus" DISPLAY=:0 notify-send "GameBoost" "$1"
    log_message "Notification sent: $1"
}

enable_game_mode() {
    if [[ ! -f "$GAMEBOOST_FLAG" ]]; then
        notify_user "Switching to performance mode"
        touch "$GAMEBOOST_FLAG"
        /usr/local/bin/gameboost/start.sh "$@" &
    fi
}

disable_game_mode() {
    if [[ -f "$GAMEBOOST_FLAG" ]]; then
        notify_user "Switching to power-saving mode"
        pkill -f '/usr/local/bin/gameboost/start.sh'
        rm -f "$GAMEBOOST_FLAG"
        /usr/local/bin/gameboost/exit.sh &
        CURRENT_PID=""
    fi
}

detect_game_process() {
    local matching_pids=()
	local game_procs=$(ps ax -o pid=,command= | sed 's|\\|/|g' \
    | grep -E "$GAME_PATTERN" \
    | grep -vE "$EXCLUDED_PATTERN")

    # Early exit if no matches
    [[ -z "$game_procs" ]] && return
    
    local pid cmdline
    while read -r pid cmdline; do
        # Skip if empty
        [[ -z "$pid" ]] && continue
        
        matching_pids+=("$pid")
        
        # Set first match as current PID if not already set
        if [[ -z "$CURRENT_PID" ]]; then
            CURRENT_PID="$pid"
            log_message "Detected game process: PID=$CURRENT_PID, CMD='$cmdline'"
        fi
    done <<< "$game_procs"
    
    # Enable game mode with all matching PIDs
    if [[ ${#matching_pids[@]} -gt 0 ]]; then
        enable_game_mode "${matching_pids[@]}"
    fi
}

verify_game_process() {
    if ! kill -0 "$CURRENT_PID" 2>/dev/null; then
        log_message "Game process ended: PID=$CURRENT_PID"
        disable_game_mode
    fi
}

# Cleanup on start
[[ -f "$GAMEBOOST_FLAG" ]] && rm -f "$GAMEBOOST_FLAG"
> "$LOG_FILE"

# Unmask potentially masked services
services=(
  upower.service
  avahi-daemon.service
  auditd.service
)

for svc in "${services[@]}"; do
    systemctl unmask "$svc" 2>/dev/null
    systemctl start "$svc"
done

# Main loop
log_message "GameBoost script started."

while true; do
    if [[ -z "$CURRENT_PID" ]]; then
        detect_game_process
    else
        verify_game_process
    fi

    sleep 10
done

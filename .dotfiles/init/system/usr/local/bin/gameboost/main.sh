#!/bin/bash

readonly GAMEBOOST_FLAG="/tmp/gameboost-running.flag"
readonly LOG_FILE="/tmp/gameboost.log"
CURRENT_PID=""

readonly GAME_PATTERNS=(
    ".*/proton waitforexitandrun"
    "minecraft.+\.jar"
    "/Games/.+\.(AppImage|x86_64|i386)$"
    "/steamapps/common/.+\.(AppImage|x86_64|i386)"
    "Hytale/.*/(HytaleClient|HytaleServer\.jar)"
    "[A-Za-z]:/.+\\.exe"
)

readonly EXCLUDED_PATTERNS=(
    "wineserver"
    "pv-adverb"
    "/dotnet"
    "/7z.exe"
    "xalia/xalia.exe"
    "bin/d3ddriverquery64.exe"
    "pressure-vessel/bin/pressure-vessel-wrap"
    "pressure-vessel/libexec/steam-runtime-tools-0/srt-bwrap"
    "(link2ea://launchgame|/Electronic Arts/EA Desktop)" # EA Games Launcher
    "C:/windows/.*"
    "/steamapps/compatdata/"
    "/winetricks"

	# FFXI
    "/Windower.exe"

    # Vortex
	"Black Tree Gaming Ltd/Vortex"
    "Vortex/Vortex.exe"

    # Modorganizer
    "ModOrganizer.exe"
    "MO2/mods"
	"MO2/explorer++"
    "MO2/loot/lootcli.exe"

    "(yay|pacman|pgrep|find|xargs|grep|awk|rsync|tar|cat)[[:space:]]"
    "/*[Ll]auncher*.exe"
    "/*[Ll]aunch[Pp]ad*.exe"
    "[Ss]etup\.exe"
    "[Ii]nstall.*\.exe"
    "[Uu]ninstall.*\.exe"
    ".*[Uu]pdate.*\.exe"
    ".*[Rr]edist.*\.exe"
)

readonly GPU_THRESHOLD=25 # Minimum threshold to run the (relatively expensive) ps+grep pattern

# Populated once at startup by detect_gpu_vendor: "nvidia", "amd", "intel", or "" (none found)
GPU_VENDOR=""
AMD_GPU_BUSY_PATH=""

# Build a single "a|b|c" regex from an array (used for GAME_PATTERN / EXCLUDED_PATTERN below)
build_pattern() {
    local IFS='|'
    echo "$*"
}

readonly GAME_PATTERN=$(build_pattern "${GAME_PATTERNS[@]}")
readonly EXCLUDED_PATTERN=$(build_pattern "${EXCLUDED_PATTERNS[@]}")

# =============================================================================
# LOGGING & NOTIFICATIONS
# =============================================================================

log_message() {
    # Builtin strftime, no `date` fork
    printf -v ts '%(%Y-%m-%d %H:%M:%S)T' -1
    echo "$ts | $1" >> "$LOG_FILE"
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

    sudo -u "$user" DBUS_SESSION_BUS_ADDRESS="$dbus" DISPLAY=:0 notify-send --app-name=GameBoost "GameBoost" "$1"
    log_message "Notification sent: $1"
}

# =============================================================================
# GPU ACTIVITY DETECTION
# =============================================================================

detect_gpu_vendor() {
    if command -v nvidia-smi &>/dev/null; then
        GPU_VENDOR="nvidia"
        log_message "GPU monitoring: using nvidia-smi"
        return
    fi

    # Prefer a discrete/amdgpu card if there are multiple DRM cards (e.g. laptop iGPU+dGPU)
    local card driver
    for card in /sys/class/drm/card*/device; do
        [[ -r "$card/gpu_busy_percent" ]] || continue
        driver=$(basename "$(readlink -f "$card/driver" 2>/dev/null)" 2>/dev/null)
        if [[ -n "$GPU_CARD" && "$card" == *"$GPU_CARD"* ]]; then
            AMD_GPU_BUSY_PATH="$card/gpu_busy_percent"
            break
        elif [[ -z "$AMD_GPU_BUSY_PATH" ]]; then
            AMD_GPU_BUSY_PATH="$card/gpu_busy_percent"
        fi
        # If we find an amdgpu-driven card, prefer it over any earlier match
        [[ "$driver" == "amdgpu" ]] && AMD_GPU_BUSY_PATH="$card/gpu_busy_percent"
    done

    if [[ -n "$AMD_GPU_BUSY_PATH" ]]; then
        GPU_VENDOR="amd"
        log_message "GPU monitoring: using $AMD_GPU_BUSY_PATH"
        return
    fi

    if command -v intel_gpu_top &>/dev/null; then
        GPU_VENDOR="intel"
        log_message "GPU monitoring: using intel_gpu_top"
        return
    fi

    log_message "GPU monitoring: no supported GPU tool found, GPU gating disabled"
}

# Sets global GPU_USAGE
get_gpu_usage() {
    GPU_USAGE="$GPU_THRESHOLD" # Should be replaced, unless implementation is faulty/missing

    case "$GPU_VENDOR" in
        nvidia)
            # Need to create implementation
            ;;
        amd)
            read -r GPU_USAGE < "$AMD_GPU_BUSY_PATH" 2>/dev/null
            ;;
		intel)
			# Need to create implementation
		    ;;
    esac

    GPU_USAGE="${GPU_USAGE%%.*}"
}

gpu_indicates_game_activity() {
    [[ -z "$GPU_VENDOR" ]] && return 0

    get_gpu_usage
    [[ "$GPU_USAGE" =~ ^[0-9]+$ ]] || return 0

    (( GPU_USAGE >= GPU_THRESHOLD ))
}

# =============================================================================
# GAME MODE CONTROL
# =============================================================================

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

# =============================================================================
# GAME PROCESS DETECTION
# =============================================================================

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

        # Check if any other game processes are still running
        local other_games=$(ps ax -o pid=,command= | sed 's|\\|/|g' \
            | grep -E "$GAME_PATTERN" \
            | grep -vE "$EXCLUDED_PATTERN")

        if [[ -n "$other_games" ]]; then
            # Other games still running - switch tracking to the first one
            local new_pid=$(echo "$other_games" | head -1 | awk '{print $1}')
            local new_cmd=$(echo "$other_games" | head -1 | cut -d' ' -f2-)
            CURRENT_PID="$new_pid"
            log_message "Switched tracking to another game: PID=$CURRENT_PID, CMD='$new_cmd'"
        else
            # No other games running - safe to disable
            disable_game_mode
        fi
    fi
}

# =============================================================================
# STARTUP
# =============================================================================

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
    # Check if service is masked
    if systemctl is-enabled "$svc" 2>&1 | grep -q masked; then
        systemctl unmask "$svc"
    fi

    # Start only if inactive
    if ! systemctl is-active --quiet "$svc"; then
        systemctl start "$svc"
    fi
done

# fd for fork-free sleep
exec {SLEEP_FD}<> <(:)

detect_gpu_vendor
log_message "GameBoost script started."

# =============================================================================
# MAIN LOOP
# =============================================================================

readonly INTERVAL=10

while true; do
    if [[ -z "$CURRENT_PID" ]]; then
        if gpu_indicates_game_activity; then
            detect_game_process
        fi
    else
        verify_game_process
    fi

    # Fork-free sleep
    read -t "$INTERVAL" -u "$SLEEP_FD" _ 2>/dev/null
done

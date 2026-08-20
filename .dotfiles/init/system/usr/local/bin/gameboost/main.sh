#!/bin/bash

readonly GAMEBOOST_FLAG="/tmp/gameboost-running.flag"
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

# calibrate_gpu_threshold() replaces it at startup with max(idle, GPU_IDLE_FLOOR) + GPU_IDLE_MARGIN.
GPU_THRESHOLD=25
readonly GPU_IDLE_FLOOR=5 GPU_IDLE_MARGIN=10

# Populated once at startup by detect_gpu_vendor: "nvidia", "amd", "intel", or "" (none found)
GPU_VENDOR=""
AMD_GPU_BUSY_PATH=""

# Build a single "a|b|c" regex from an array (used for GAME_PATTERN / EXCLUDED_PATTERN below)
build_slash_tolerant_pattern() {
	local SLASH_CLASS='[/\]' IFS='|'
    printf '%s' "${*//\//$SLASH_CLASS}"
}

readonly GAME_PATTERN=$(build_slash_tolerant_pattern "${GAME_PATTERNS[@]}")
readonly EXCLUDED_PATTERN=$(build_slash_tolerant_pattern "${EXCLUDED_PATTERNS[@]}")

# =============================================================================
# NOTIFICATIONS
# =============================================================================

notify_user() {
    local session=$(loginctl list-sessions --no-legend | awk '{print $1}' | while read -r id; do
        [[ $(loginctl show-session "$id" -p Active --value) == yes ]] && \
        [[ $(loginctl show-session "$id" -p Type --value) =~ ^(x11|wayland)$ ]] && { echo "$id"; break; }
    done)
    [[ -z "$session" ]] && return

    local user=$(loginctl show-session "$session" -p Name --value) uid
    uid=$(id -u "$user")
    sudo -u "$user" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" DISPLAY=:0 \
        notify-send --app-name=GameBoost "GameBoost" "$1"
    echo "Notification sent: $1"
}

# =============================================================================
# GPU ACTIVITY DETECTION
# =============================================================================

detect_gpu_vendor() {
    if command -v nvidia-smi &>/dev/null; then
        GPU_VENDOR="NVIDIA"
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
        [[ "$driver" == "amdgpu" ]] && AMD_GPU_BUSY_PATH="$card/gpu_busy_percent"
    done
    [[ -n "$AMD_GPU_BUSY_PATH" ]] && { GPU_VENDOR="AMD"; return; }

    command -v intel_gpu_top &>/dev/null && GPU_VENDOR="INTEL"
}

# Sets global GPU_USAGE
get_gpu_usage() {
    GPU_USAGE="$GPU_THRESHOLD" # Should be replaced, unless implementation is faulty/missing

    case "$GPU_VENDOR" in
        NVIDIA) ;; # Need to create implementation
        AMD)    read -r GPU_USAGE < "$AMD_GPU_BUSY_PATH" 2>/dev/null ;;
        INTEL)  ;; # Need to create implementation
    esac

    GPU_USAGE="${GPU_USAGE%%.*}"
}

# GPU_THRESHOLD = max(idle, GPU_IDLE_FLOOR) + GPU_IDLE_MARGIN.
calibrate_gpu_threshold() {
    if [[ -z "$GPU_VENDOR" ]]; then
        return
    fi

    get_gpu_usage
    if [[ "$GPU_USAGE" =~ ^[0-9]+$ ]]; then
        GPU_THRESHOLD=$(( (GPU_USAGE < GPU_IDLE_FLOOR ? GPU_IDLE_FLOOR : GPU_USAGE) + GPU_IDLE_MARGIN ))
    fi
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

# Prints "pid<TAB>cmdline" for every running process that matches GAME_PATTERN
# and isn't excluded by EXCLUDED_PATTERN. Shared by detect/verify below.
scan_games() {
    ps ax -o pid=,command= | grep -E "$GAME_PATTERN" | while read -r pid cmdline; do
        [[ "$cmdline" =~ $EXCLUDED_PATTERN ]] || printf '%s\t%s\n' "$pid" "$cmdline"
    done
}

detect_game_process() {
    local matches; matches=$(scan_games)
    [[ -z "$matches" ]] && return

    local pid cmdline pids=()
    while IFS=$'\t' read -r pid cmdline; do
        pids+=("$pid")
        if [[ -z "$CURRENT_PID" ]]; then
            CURRENT_PID="$pid"
            echo "Detected game process: PID=$CURRENT_PID, CMD='${cmdline//\\//}'"
        fi
    done <<< "$matches"

    enable_game_mode "${pids[@]}"
}

verify_game_process() {
    kill -0 "$CURRENT_PID" 2>/dev/null && return
    echo "Game process ended: PID=$CURRENT_PID"

    local pid cmdline
    IFS=$'\t' read -r pid cmdline <<< "$(scan_games)"

    if [[ -n "$pid" ]]; then
        CURRENT_PID="$pid"
        echo "Switched tracking to another game: PID=$CURRENT_PID, CMD='${cmdline//\\//}'"
    else
        disable_game_mode
    fi
}

# =============================================================================
# STARTUP
# =============================================================================

rm -f "$GAMEBOOST_FLAG"

for svc in upower.service avahi-daemon.service auditd.service; do
    systemctl is-enabled "$svc" 2>&1 | grep -q masked && systemctl unmask "$svc"
    systemctl is-active --quiet "$svc" || systemctl start "$svc"
done

# fd for fork-free sleep
exec {SLEEP_FD}<> <(:)

detect_gpu_vendor
echo "GPU vendor: ${GPU_VENDOR:-none found}"

# Derive the threshold from gpu idle: max(idle, 5%) + 10%.
calibrate_gpu_threshold
echo "GPU threshold: ${GPU_THRESHOLD}%"

# =============================================================================
# MAIN LOOP
# =============================================================================

readonly INTERVAL=10

while true; do
    if [[ -z "$CURRENT_PID" ]]; then
        gpu_indicates_game_activity && detect_game_process
    else
        verify_game_process
    fi

    read -t "$INTERVAL" -u "$SLEEP_FD" _ 2>/dev/null # fork-free sleep
done

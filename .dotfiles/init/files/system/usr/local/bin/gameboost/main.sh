#!/bin/bash

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly GAMEBOOST_FLAG="/tmp/gameboost-running.flag"
CURRENT_PID=""

readonly GAME_PATTERNS=(
    ".*/proton waitforexitandrun"
    "minecraft.+\.jar"
    "/Games/.+\.(AppImage|x86_64|i386)$"
    "/steamapps/common/.+\.(AppImage|x86_64|i386)"
    "Hytale/.*/(HytaleClient|HytaleServer\.jar)"
    "[A-Za-z]:/.+\\.exe"
    "ProjectZomboid64"
)

readonly EXCLUDED_PATTERNS=(
    "\.sh$"
    "wineserver"
    "pv-adverb"
    "/dotnet"
    "/7z.exe"
    "xalia/xalia.exe"
    "bin/d3ddriverquery64.exe"
    "pressure-vessel/bin/pressure-vessel-wrap"
    "pressure-vessel/libexec/steam-runtime-tools-0/srt-bwrap"
    "(link2ea://launchgame|/Electronic Arts/EA Desktop)"
    "C:/windows/.*"
    "/steamapps/compatdata/"
    "/winetricks"

    # Project Zomboid Server
    "ProjectZomboid64 -servername"

    # FFXI
    "/Windower.exe"

    # Vortex
    "Black Tree Gaming Ltd/Vortex" "Vortex/Vortex.exe"

    # Modorganizer
    "ModOrganizer.exe" "MO2/mods" "MO2/explorer++" "MO2/loot/lootcli.exe"

    "(yay|pacman|pgrep|find|xargs|grep|awk|rsync|tar|cat)[[:space:]]"
    "/*[Ll]auncher*.exe"
    "/*[Ll]aunch[Pp]ad*.exe"
    "[Ss]etup\.exe"
    "[Ii]nstall.*\.exe"
    ".*[Uu]pdate.*\.exe"
    ".*[Rr]edist.*\.exe"
)

readonly OPTIMIZED_PS_SRC="$SCRIPT_DIR/optimized_ps.c"
readonly OPTIMIZED_PS="$SCRIPT_DIR/optimized_ps"

# Calibrated at startup: max(gpu_idle, GPU_IDLE_FLOOR) + GPU_IDLE_MARGIN.
GPU_THRESHOLD=25
readonly GPU_IDLE_FLOOR=5 GPU_IDLE_MARGIN=10

# Populated by detect_gpu_vendor: "NVIDIA", "AMD", "INTEL", or "".
GPU_VENDOR=""
AMD_GPU_BUSY_PATH=""

# Build a single "a|b|c" regex from an array.
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
    local session user uid

    while read -r session _; do
        [[ $(loginctl show-session "$session" -p Active --value) == yes ]] &&
        [[ $(loginctl show-session "$session" -p Type --value) =~ ^(x11|wayland)$ ]] || continue

        user=$(loginctl show-session "$session" -p Name --value)
        uid=$(id -u "$user")

        runuser -u "$user" -- env \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" DISPLAY=:0 \
            notify-send --app-name=GameBoost GameBoost "$1"

        echo "Notification sent: $1"
        return
    done < <(loginctl list-sessions --no-legend 2>/dev/null)
}

# =============================================================================
# GPU ACTIVITY DETECTION
# =============================================================================

detect_gpu_vendor() {
    if command -v nvidia-smi &>/dev/null; then
        GPU_VENDOR="NVIDIA"
        return
    fi

    # Prefer a discrete/amdgpu card if there are multiple DRM cards.
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

    if [[ -n "$AMD_GPU_BUSY_PATH" ]]; then
        GPU_VENDOR="AMD"
    elif command -v intel_gpu_top &>/dev/null; then
        GPU_VENDOR="INTEL"
    fi
}

update_gpu_usage() {
    GPU_USAGE="$GPU_THRESHOLD"

    case "$GPU_VENDOR" in
        NVIDIA) ;;
        AMD)    read -r GPU_USAGE < "$AMD_GPU_BUSY_PATH" 2>/dev/null ;;
        INTEL)  ;;
    esac

    GPU_USAGE="${GPU_USAGE%%.*}"
}

calibrate_gpu_threshold() {
    [[ -n "$GPU_VENDOR" ]] || return
    update_gpu_usage

    if [[ "$GPU_USAGE" =~ ^[0-9]+$ ]]; then
        GPU_THRESHOLD=$(( (GPU_USAGE < GPU_IDLE_FLOOR ? GPU_IDLE_FLOOR : GPU_USAGE) + GPU_IDLE_MARGIN ))
    fi
}

gpu_indicates_game_activity() {
    [[ -n "$GPU_VENDOR" ]] || return 0
    update_gpu_usage
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
        $SCRIPT_DIR/start.sh "$@" &
    fi
}

disable_game_mode() {
    if [[ -f "$GAMEBOOST_FLAG" ]]; then
        notify_user "Switching to power-saving mode"
        pkill -f "$SCRIPT_DIR/start.sh"
        rm -f "$GAMEBOOST_FLAG"
        $SCRIPT_DIR/exit.sh &
        CURRENT_PID=""
    fi
}

# =============================================================================
# GAME PROCESS DETECTION
# =============================================================================

# Compile optimized_ps only when optimized_ps.c has changed.
build_optimized_ps() {
    local sha="$OPTIMIZED_PS.sha256"
    local hash=$(sha256sum "$OPTIMIZED_PS_SRC" | cut -d' ' -f1)

    if [[ ! -x "$OPTIMIZED_PS" || ! -f "$sha" || "$hash" != "$(cat "$sha")" ]]; then
        gcc -O3 -march=native "$OPTIMIZED_PS_SRC" -o "$OPTIMIZED_PS" || exit 1
        echo "$hash" > "$sha"
    fi
}

# Prints "pid<TAB>cmdline" for every running process matching GAME_PATTERN.
scan_games() {
    "$OPTIMIZED_PS" | grep -E "$GAME_PATTERN" |
        while read -r pid cmdline; do
            [[ "$cmdline" =~ $EXCLUDED_PATTERN ]] ||
                printf '%s\t%s\n' "$pid" "$cmdline"
        done
}

detect_game_process() {
    local matches=$(scan_games)
    [[ -n "$matches" ]] || return

    local pid cmdline pids=()
    while IFS=$'\t' read -r pid cmdline; do
        pids+=("$pid")

        if [[ -z "$CURRENT_PID" ]]; then
            CURRENT_PID="$pid"
            echo "Detected game process: PID=$pid, CMD='${cmdline//\\//}'"
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
        echo "Switched tracking to another game: PID=$pid, CMD='${cmdline//\\//}'"
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

# Optimized ps replacement to reduce CPU time during process scanning.
build_optimized_ps

detect_gpu_vendor
echo "GPU vendor: ${GPU_VENDOR:-none found}"

calibrate_gpu_threshold
echo "GPU threshold: ${GPU_THRESHOLD}%"

# =============================================================================
# MAIN LOOP
# =============================================================================

exec {SLEEP_FD}<> <(:)

while :; do
    if [[ "$CURRENT_PID" ]]; then
        verify_game_process
    elif gpu_indicates_game_activity; then
        detect_game_process
    fi

    read -rt 10 -u "$SLEEP_FD" _ || :
done

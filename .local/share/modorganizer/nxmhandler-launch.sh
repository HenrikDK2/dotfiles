#!/usr/bin/env bash

DEBUG="${DEBUG:-0}"

log() { [[ "$DEBUG" == "1" ]] && echo "[DEBUG] $*"; }
fail() { echo "[ERROR] $*" >&2; zenity --error --text="$*"; exit 1; }

[[ $# -ge 1 ]] || fail "Provide NXM link"

nxm_link="$1"
nexus_game_id="${nxm_link#nxm://}"
nexus_game_id="${nexus_game_id%%/*}"

log "NXM: $nxm_link"
log "Game ID: $nexus_game_id"

STEAMAPPS="${STEAMAPPS_PATH:-$HOME/Games/steamapps}"
COMPATDATA="$STEAMAPPS/compatdata"

CACHE_FILE="$HOME/.cache/mo2-nxm-cache.json"
mkdir -p "$(dirname "$CACHE_FILE")"

log "Cache file: $CACHE_FILE"

get_cached_instance() {
    jq -r --arg id "$1" '.[$id].exe // empty' "$CACHE_FILE" 2>/dev/null || true
}

get_cached_appid() {
    jq -r --arg id "$1" '.[$id].appid // empty' "$CACHE_FILE" 2>/dev/null || true
}

update_cache() {
    local appid="$1"
    local exe="$2"

    log "Updating cache: $appid -> $exe"

    tmp="$(mktemp)"
    jq --arg id "$appid" --arg exe "$exe" \
        '.[$id] = {appid:$id, exe:$exe}' \
        "$CACHE_FILE" 2>/dev/null > "$tmp" || echo "{}" > "$tmp"

    mv "$tmp" "$CACHE_FILE"
}

cached_exe="$(get_cached_instance "$nexus_game_id")"
cached_appid="$(get_cached_appid "$nexus_game_id")"

if [[ -n "$cached_exe" && -f "$cached_exe" ]]; then
    log "Cache HIT: $cached_exe"
    instance_exe="$cached_exe"
    game_steam_id="$cached_appid"
else
    log "Cache MISS → scanning compatdata"

    mapfile -t mo2_instances < <(
        find "$COMPATDATA" -type f -iname "ModOrganizer.exe" 2>/dev/null
    )

    [[ ${#mo2_instances[@]} -gt 0 ]] || fail "No MO2 instances found"

    extract_appid() {
        echo "$1" | grep -oP '(?<=/compatdata/)\d+(?=/pfx/)'
    }

    appid_to_name() {
        local appid="$1"
        local acf="$STEAMAPPS/appmanifest_${appid}.acf"

        if [[ -f "$acf" ]]; then
            grep -m1 '"name"' "$acf" | sed 's/.*"name"[[:space:]]*"\(.*\)"/\1/'
        else
            echo "$appid"
        fi
    }

    instance_exe=""
    game_steam_id=""
    game_name=""

    for exe in "${mo2_instances[@]}"; do
        appid="$(extract_appid "$exe")"
        name="$(appid_to_name "$appid")"

        log "Checking $appid → $name"

        if [[ "${name,,}" == *"${nexus_game_id,,}"* ]]; then
            instance_exe="$exe"
            game_steam_id="$appid"
            game_name="$name"
            break
        fi
    done

    # fallback
    if [[ -z "$instance_exe" ]]; then
        log "No match → fallback first instance"
        instance_exe="${mo2_instances[0]}"
        game_steam_id="$(extract_appid "$instance_exe")"
        game_name="$(appid_to_name "$game_steam_id")"
    fi

    update_cache "$game_steam_id" "$instance_exe"
fi

instance_dir="$(dirname "$instance_exe")"

log "Selected:"
log "  exe: $instance_exe"
log "  appid: $game_steam_id"
log "  dir: $instance_dir"

run_nxmhandler() {
    protontricks-launch \
        --appid "$game_steam_id" \
        "$instance_dir/nxmhandler.exe" \
        "$nxm_link" &

    log "nxmhandler launched"
    auto_kill_nxmhandler &
}

auto_kill_nxmhandler() {
    sleep 20

    log "Attempting nxmhandler cleanup"

    if pkill -f nxmhandler.exe; then
        log "Killed nxmhandler"
    else
        log "No nxmhandler process found"
    fi
}

run_nxmhandler

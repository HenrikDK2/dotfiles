#!/usr/bin/env bash

set -uo pipefail

DAYS="${TRASH_MAX_AGE_DAYS:-30}"
NOW_EPOCH=$(date +%s)
CUTOFF_EPOCH=$(( NOW_EPOCH - DAYS * 86400 ))

log() {
    logger -t trash-cleanup -- "$*" 2>/dev/null
    echo "$*"
}

# Convert an ISO-8601-ish DeletionDate (YYYY-MM-DDTHH:MM:SS) to epoch.
# Returns empty string on failure.
parse_deletion_epoch() {
    local ts="$1"
    date -d "$ts" +%s 2>/dev/null
}

process_trash_dir() {
    local trash_dir="$1"
    local files_dir="$trash_dir/files"
    local info_dir="$trash_dir/info"

    [ -d "$files_dir" ] || return 0

    local removed=0

    shopt -s dotglob nullglob
    local item
    for item in "$files_dir"/*; do
        [ -e "$item" ] || continue
        local base
        base="$(basename "$item")"
        local info_file="$info_dir/${base}.trashinfo"

        local item_epoch=""

        if [ -f "$info_file" ]; then
            local deletion_date
            deletion_date="$(grep -m1 '^DeletionDate=' "$info_file" 2>/dev/null | cut -d= -f2-)"
            if [ -n "$deletion_date" ]; then
                item_epoch="$(parse_deletion_epoch "$deletion_date")"
            fi
        fi

        # Fall back to the trashed item's own mtime if no usable info file.
        if [ -z "$item_epoch" ]; then
            item_epoch="$(stat -c %Y "$item" 2>/dev/null)"
        fi

        [ -n "$item_epoch" ] || continue

        if [ "$item_epoch" -lt "$CUTOFF_EPOCH" ]; then
            rm -rf -- "$item"
            rm -f -- "$info_file"
            removed=$((removed + 1))
        fi
    done
    shopt -u dotglob nullglob

    # Clean any orphaned .trashinfo files whose target no longer exists.
    if [ -d "$info_dir" ]; then
        local info
        for info in "$info_dir"/*.trashinfo; do
            [ -e "$info" ] || continue
            local target_base
            target_base="$(basename "$info" .trashinfo)"
            [ -e "$files_dir/$target_base" ] || rm -f -- "$info"
        done
    fi

    if [ "$removed" -gt 0 ]; then
        log "Removed $removed item(s) older than ${DAYS}d from $trash_dir"
    fi
}

main() {
    local home_dir user trash_dir
    for home_dir in /home/*; do
        [ -d "$home_dir" ] || continue
        user="$(basename "$home_dir")"
        trash_dir="$home_dir/.local/share/Trash"
        [ -d "$trash_dir" ] || continue

        # Skip if not actually owned appropriately / is a symlink trick.
        if [ -L "$trash_dir" ]; then
            log "Skipping $trash_dir for user $user: refusing to follow symlink"
            continue
        fi

        process_trash_dir "$trash_dir"
    done
}

main "$@"

#!/bin/bash

# Set lowest CPU priority (19 is lowest, 0 is default)
# Set idle (best-effort) I/O class and lowest priority (7 is lowest)
ionice -c 3 -n 7 -p $$ >/dev/null 2>&1
nice -n 19 -p $$ >/dev/null 2>&1

AUDIT_FLAG="/tmp/audit.flag"
GAMEBOOST_FLAG="/tmp/gameboost-running.flag"
MTIME_STORE="/tmp/audit_last_mtime"

# Load last known mtime from file if it exists
if [[ -f "$MTIME_STORE" ]]; then
    last_mtime=$(cat "$MTIME_STORE")
else
    last_mtime=$(stat -c %Y "$AUDIT_FLAG" 2>/dev/null)
    echo "$last_mtime" > "$MTIME_STORE"
fi

# Function to update stored mtime on exit
cleanup() {
    echo "$last_mtime" > "$MTIME_STORE"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

while true; do
    if [ ! -f "$GAMEBOOST_FLAG" ]; then
        current_mtime=$(stat -c %Y "$AUDIT_FLAG" 2>/dev/null)

        if [[ "$current_mtime" != "$last_mtime" ]]; then
            last_mtime=$current_mtime
            exec $HOME/.dotfiles/scripts/audit.sh -b &
        fi

        sleep 5
    else
        sleep 30
    fi
done

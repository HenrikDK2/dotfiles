#!/bin/bash
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_FILE="$CACHE_DIR/has_run.lock"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$(realpath "$0")"

section() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

wait_for_internet() {
    local timeout=300
    local elapsed=0
    echo "Waiting for internet connection..."
    while ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; do
        if (( elapsed >= timeout )); then
            echo "No internet connection after 5 minutes. Exiting."
            exit 1
        fi
        sleep 2
        (( elapsed += 2 ))
    done
    echo "Internet connected."
}

main() {
    wait_for_internet

    section "Setting Default Shell"
    sudo usermod -s /usr/bin/fish "$USER"

    section "Packages"
    "$SCRIPT_DIR/scripts/packages.sh"

    section "Services"
    "$SCRIPT_DIR/scripts/services.sh"

    section "Custom system tuning service"
    "$SCRIPT_DIR/scripts/system-tuning/install.sh"

    section "Drive Optimizations"
    "$SCRIPT_DIR/scripts/drive_optimizations.sh"

    section "Mozilla"
    "$SCRIPT_DIR/scripts/mozilla.sh"

    section "qBittorrent"
    "$SCRIPT_DIR/scripts/qbittorrent.sh"

    section "Fix Paths"
    "$SCRIPT_DIR/scripts/fix_paths.sh"

    section "Finalizing"
    git update-index --skip-worktree "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" || true
    touch "$CACHE_FILE"

    for i in {5..1}; do echo "Rebooting in $i..."; sleep 1; done; reboot
}

if [[ -t 1 ]]; then
    main
elif [ ! -f "$CACHE_FILE" ]; then
    konsole -e bash "$SCRIPT_PATH"
fi

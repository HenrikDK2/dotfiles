#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERR ]${RESET}  $*"; }

# Packages to install
FLATPAK_PACKAGES=(
    "com.discordapp.Discord"
    "com.mastermindzh.tidal-hifi"
    "io.github.ilya_zlobintsev.LACT"
    "org.mozilla.Thunderbird"
    "org.mozilla.firefox"
    "org.qbittorrent.qBittorrent"
)

BREW_PACKAGES=(
    "micro"
)

# Helper Functions
install_flatpak() {
    local pkg="$1"
    local name
    name=$(echo "$pkg" | awk -F. '{print $NF}')

    if flatpak list --app | grep -q "^${pkg}"; then
        warn "${name} is already installed — skipping"
    else
        info "Installing ${name} (${pkg})…"
        if flatpak install -y flathub "$pkg" 2>&1; then
            success "${name} installed"
        else
            error "Failed to install ${name}"
        fi
    fi
}

install_brew() {
    local pkg="$1"

    if brew list "$pkg" &>/dev/null; then
        warn "${pkg} is already installed — skipping"
    else
        info "Installing ${pkg} via Homebrew…"
        if brew install "$pkg" 2>&1; then
            success "${pkg} installed"
        else
            error "Failed to install ${pkg}"
        fi
    fi
}


# Install flatpak packages
echo ""
echo -e "${BOLD}── Flatpak packages ─────────────────────────────${RESET}"
echo ""

# Ensure Flathub remote is added
if ! flatpak remotes | grep -q "flathub"; then
    info "Adding Flathub remote…"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

for pkg in "${FLATPAK_PACKAGES[@]}"; do
    install_flatpak "$pkg"
done

# Install Homebrew packages
echo ""
echo -e "${BOLD}── Homebrew packages ────────────────────────────${RESET}"
echo ""

for pkg in "${BREW_PACKAGES[@]}"; do
    install_brew "$pkg"
done

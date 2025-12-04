#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"

# ANSI escape codes for colors
yellow='\033[1;33m'
green='\033[1;32m'
red='\033[1;31m'
blue='\033[1;34m'
reset='\033[0m'

packages=(
	"dnf-automatic"
	"NetworkManager-openvpn.x86_64"

	"code"
	"discord"
	"mangohud"
	"gamescope"
	"qbittorrent"
	"btop"

	"fuse"
	"fuse-libs"
	"mpg123"
	"zstd"
)

flathub_packages=(
	"com.mastermindzh.tidal-hifi"
	"com.valvesoftware.Steam"
	"com.heroicgameslauncher.hgl"
	"com.valvesoftware.Steam.CompatibilityTool.Proton-GE"
	"org.freedesktop.Platform.VulkanLayer.gamescope"
)

packages_to_remove=(
	"libreoffice*"
	"rhythmbox.*"
	"irqbalance"
	"malcontent*"
	"system-config-language.*"
	"nheko.*"
)

# Commmonly shared functions used by all scripts
source "$DIR/scripts/functions.sh"

separator "Copying custom system files..."
sudo cp -r "$DIR/system/"* /

separator "Enabling custom services..."
sudo systemctl enable \
	gameboost.service \
	system-tuning.service \
	fstrim.timer \
	dnf-automatic.timer

systemctl enable --user flatpak-update.timer

separator "Setting up RPM Fusion & Third-party Repos..."
sudo dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

sudo sh -c 'echo -e "[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

sudo dnf upgrade -y --refresh

separator "Installing & removing packages..."
sudo dnf install -y "${packages[@]}"
flatpak install -y flathub "${flathub_packages[@]}"
sudo dnf remove -y "${packages_to_remove[@]}"

source "$DIR/scripts/video_playback_fix.sh"
source "$DIR/scripts/automatic_updates.sh"
source "$DIR/scripts/code_extensions.sh"
source "$DIR/scripts/heroic.sh"
source "$DIR/scripts/qbittorrent.sh"
source "$DIR/scripts/mozilla.sh"
source "$DIR/scripts/drive_optimizations.sh"
source "$DIR/scripts/kernel_params.sh"
source "$DIR/scripts/firewall.sh"
source "$DIR/scripts/amd_oc.sh"

clear_screen
echo -e "Install ${green}DONE!${reset} Please ${yellow}reboot${reset} system..."

#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEZONE="Europe/Copenhagen"
USERNAME="henrik"
HOME="/home/$USERNAME"
PACKAGES=(
	"linux-firmware"
	"linux-zen"
	"base"
	"base-devel"

	# Network
	"networkmanager"
	"networkmanager-openvpn"
	"network-manager-applet"
	"ufw"

	# System
    "alacritty"
    "jq"
	"bash-completion"
    "btop"
    "cabextract"
    "fastfetch"
    "fuse"
    "grim"
    "gvfs"
    "gvfs-mtp"
    "imv"
    "mako"
    "man-db"
    "micro"
    "mpv"
    "nemo"
    "nemo-fileroller"
    "npm"
    "polkit"
    "polkit-gnome"
    "rofi"
    "rofi-calc"
    "socat"
    "scrot"
    "seahorse"
    "slurp"
    "swappy"
    "hyprland"
    "hyprlock"
    "swaybg"
    "unrar"
    "unzip"
    "waybar"
    "xdg-desktop-portal-hyprland"
    "xorg-xwayland"
    "papirus-icon-theme"
    "wl-clipboard"
    "7zip"

    # Misc
    "qbittorrent"
    "thunderbird"
    "code"

    # Gaming
    "discord"
    "wine"
    "gamescope"
    "lib32-mangohud"
    "mangohud"
    "steam"

	# Audio
	"pipewire"
	"pipewire-audio"
	"pipewire-pulse"
	"wireplumber"
	"pavucontrol"

	# Fonts
	"cantarell-fonts"
	"otf-font-awesome"
	"ttf-jetbrains-mono"
	"ttf-droid"
	"ttf-dejavu"
)

function is_chroot() {
	if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
		return 0
	else
		return 1
	fi
}

# $1 - offset from top (default: 0)
function clear_screen() {
    local lines=$(tput lines)
    local offset=${1:-0}
    local clear_lines=$((lines - offset))

    if (( clear_lines < 0 )); then
        clear_lines=0
    fi

    # Push old content off
    for ((i=0; i<clear_lines; i++)); do
        echo ""
    done

    # Move prompt up by printing blank lines after clearing
    tput cup "$offset" 0
}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' does not exist. Exiting...."
    exit 1
fi

# Check if .dotfiles is inside home directory
if ! [ -d "$HOME/.dotfiles" ]; then
    echo "Dotfiles are not initialized at '$HOME/.dotfiles'"
	exit 1
fi

# Make sure user is part of %wheel group
usermod -a -G wheel "$USERNAME"

# Enable multilib, DisableDownloadTimeout, and ParallelDownloads
if ! grep -q "DisableDownloadTimeout" "/etc/pacman.conf"; then
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
	sed -i "/ParallelDownloads/c\ParallelDownloads = 10\nDisableDownloadTimeout" /etc/pacman.conf
	pacman -Suuy
fi

# Copy system configs & install system packages
cp -rf $SCRIPT_DIR/system/* /
pacman -Syu ${PACKAGES[@]} --ask 4 --needed

# Enable essential system services
systemctl enable \
    avahi-daemon.service \
    ufw.service \
    gameboost.service \
    NetworkManager.service \
    cap_sys_nice.service \
    pacman-remove-db-lock.service \
    system-tuning.service \
    fstrim.timer \
    clean-cache.timer

# Mask unwanted services
systemctl mask \
    systemd-userdbd \
    systemd-resolved \
    systemd-userdbd.socket \
    accounts-daemon \
    rtkit-daemon \
    ldconfig

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set localization
sed -i 's/^#da_DK.UTF-8 UTF-8/da_DK.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo "LANG=da_DK.UTF-8" | tee /etc/locale.conf
echo "LC_TIME=en_US.UTF-8" | tee -a /etc/locale.conf
echo "KEYMAP=dk" | tee /etc/vconsole.conf
locale-gen

# Set hostname
echo "arch" | tee /etc/hostname

# Setup password for root user
if is_chroot; then
	passwd
fi

# Run commands in user context
loginctl enable-linger "$USERNAME"
systemd-run --machine="$USERNAME@.host" --user --wait systemctl --user enable wireplumber psd
systemd-run --machine="$USERNAME@.host" --user --wait systemctl --user mask at-spi-dbus-bus

source $SCRIPT_DIR/scripts/bootloader.sh
source $SCRIPT_DIR/scripts/mozilla.sh
source $SCRIPT_DIR/scripts/qbittorrent.sh
source $SCRIPT_DIR/scripts/drive_optimizations.sh
source $SCRIPT_DIR/scripts/auto_update.sh
source $SCRIPT_DIR/scripts/firewall.sh
source $SCRIPT_DIR/scripts/auto_login.sh
source $SCRIPT_DIR/scripts/gpu_drivers.sh

# This will regenerate the initial ramdisk environment for all installed kernels
mkinitcpio -P

# Make user part of the games group (Allows proton to set niceness of process)
usermod -a -G games "$USERNAME"

# Enable network time sync
timedatectl set-ntp true

# Remove initial pacsave/pacnew files
find /etc \( -name "*.pacnew" -o -name "*.pacsave" \) -print0 | xargs -0 rm -f

# Reboot
for i in {5..1}; do echo "Rebooting in $i..."; sleep 1; done; reboot

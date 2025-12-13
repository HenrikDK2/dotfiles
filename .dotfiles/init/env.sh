#!/bin/bash

USERNAME="henrik"
HOSTNAME="arch"

# Timezone
TIMEZONE="Europe/Copenhagen"

# Localization
LOCALES=("da_DK.UTF-8 UTF-8" "en_US.UTF-8 UTF-8")
LANG="en_US.UTF-8"
LC_TIME="da_DK.UTF-8"
KEYMAP="dk"

##############################
# DON'T CHANGE ANYTHING BELOW
##############################

# Colors
YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
RESET='\033[0m'

# Repo
GITHUB_REPO_SSH="git@github.com:HenrikDK2/dotfiles.git"
GITHUB_REPO="https://github.com/HenrikDK2/dotfiles.git"

HOME="/home/$USERNAME"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"

PACKAGES=(
	"linux-firmware"
	"linux-zen"
	"base"
	"base-devel"

	# Network
	"networkmanager"
	"networkmanager-openvpn"
	"network-manager-applet"
	"modemmanager"
	"ufw"

	# Printer
	"cups"
	"avahi"
	"ghostscript"
	"nss-mdns"
	"system-config-printer"

	# Bluetooth (system-tuning service disable this service on boot, if no bluetooth capable device is detected)
	"bluez"
	"bluez-utils"
	"blueman"
	
	# System
    "alacritty"
    "jq"
	"bash-completion"
    "btop"
    "cabextract"
    "fastfetch"
    "fuse"
    "fish"
    "grim"
    "gvfs"
    "git"
    "gvfs-mtp"
    "imv"
    "flatpak"
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
    "xdg-desktop-portal-gtk" # xdg-desktop-portal-hyprland doesn't offer a fileChooser
    "xorg-xwayland"
    "papirus-icon-theme"
    "wl-clipboard"
    "7zip"

    # Misc
    "discord"
    "qbittorrent"
    "thunderbird"
    "firefox"
    "code"

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

FLATHUB_PACKAGES=(
	"com.mastermindzh.tidal-hifi"
	"com.valvesoftware.Steam"
	"com.heroicgameslauncher.hgl"
	"com.valvesoftware.Steam.CompatibilityTool.Proton-GE"
	"org.freedesktop.Platform.VulkanLayer.MangoHud"
	"org.freedesktop.Platform.VulkanLayer.gamescope"
	"com.github.tchx84.Flatseal"
)

SYSTEM_SERVICES_TO_ENABLE=(
    "avahi-daemon.service"
    "cups.service"
    
    "ufw.service"
    "NetworkManager.service"
	"NetworkManager-wait-online.service"
	
    "gameboost.service"
    "system-tuning.service"

    "pacman-remove-db-lock.service"
    "fstrim.timer"
    "clean-cache.timer"
)

SYSTEM_SERVICES_TO_MASK=(
    "systemd-userdbd.service"
    "systemd-userdbd.socket"

    "systemd-resolved.service"
    "accounts-daemon.service"
    "rtkit-daemon.service"
    "ldconfig.service"
)

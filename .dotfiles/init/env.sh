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
USER=$USERNAME

PACKAGES=(
	"linux-firmware"
	"linux-lts" # Backup
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
    "brightnessctl"
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
    "hyprpicker"
    "hypridle"
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

	# Sandboxing
    "firejail"
    "apparmor"
    "xdg-dbus-proxy"
    
	# TLP is only enabled when using a laptop
    "tlp" 
    "tlp-rdw"

    # Misc
    "discord"
    "qbittorrent"
    "thunderbird"
    "firefox"
    "code"

	# Gaming
	"steam"
    "gamescope"
    "mangohud"

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

SYSTEM_SERVICES_TO_ENABLE=(
    "avahi-daemon.service"
    "cups.service"
    
    "ufw.service"
    "NetworkManager.service"
	"NetworkManager-wait-online.service"

	"apparmor.service"
	
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

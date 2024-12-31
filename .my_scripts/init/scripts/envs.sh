#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'

prerequisites_packages=(
    "linux-firmware"
    "base"
    "base-devel"
    "mkinitcpio"

    "sudo"
    "git"
    "bc"
    "curl"
    "jq"
    "connman"

    # Makepkg related packages (Flags in ~/.makepkg.conf)
    "mold"
    "zstd"
    "pigz"
    "pbzip2"
    "xz"
)

packages=(
    # Fonts
    "cantarell-fonts"
    "otf-font-awesome"
    "ttf-jetbrains-mono"
    "ttf-ms-win10-auto"
    "ttf-droid"
    "ttf-dejavu"

    # Sound
    "pipewire"
    "pipewire-audio"
    "pipewire-alsa"
    "pipewire-jack"
    "pipewire-pulse"
    "wireplumber"
    "pavucontrol"

    # Networking
    "cmst"
    "connman"
    "dnsmasq"
    "ufw"

    # System
    "alacritty"
	"bash-completion"
	"blesh-git"
    "btop"
    "cabextract"
    "cups"
    "dconf"
    "fuse"
    "glib2"
    "gnome-calculator"
    "gnome-keyring"
    "grim"
    "gvfs"
    "gvfs-mtp"
    "imv"
    "lib32-mangohud"
    "libappindicator-gtk2"
    "libappindicator-gtk3"
    "libsecret"
    "mako"
    "man-db"
    "micro"
    "mpv"
    "nemo"
    "nemo-fileroller"
    "npm"
    "ntfs-3g"
    "openvr"
    "p7zip"
    "polkit"
    "polkit-gnome"
    "python-pip"
    "qt5-declarative"
    "qt5-wayland"
    "qt6-declarative"
    "qt6-wayland"
    "scrot"
    "seahorse"
    "slurp"
    "swappy"
    "sway"
    "swaybg"
    "swaylock-effects-git"
    "tesseract-data-eng"
    "unrar"
    "unzip"
    "waybar"
    "wayland-protocols"
    "wofi"
    "xdg-desktop-portal"
    "xdg-desktop-portal-wlr"
    "xorg-xwayland"
    "wl-clipboard"

    # Gaming
    "proton-ge-custom-bin"
    "discord-canary"
    "wine"
    "wine-gecko"
    "wine-mono"
    "gamescope"
    "heroic-games-launcher-bin"
    "lib32-mangohud"
    "mangohud"
    "steam"

    # Misc
    "code"
    "deluge"
    "deluge-gtk"
    "firefox"
    "thunderbird"
)

kernel_packages=(
	"linux-zen"
	"linux"
	"linux-lts"
	"linux-hardened"
	"linux-rt"
	"linux-rt-lts"
    "linux-tkg.*"
)

android_development_packages=(
	"watchman-bin"
	"python"
	"jdk-openjdk"
	"jdk17-openjdk"
	"android-tools"
	"android-studio"
)

obs_packages=(
	"obs-studio-browser"
	"obs-vkcapture"
)

virt_manager_packages=(
	"virt-manager"
	"qemu-desktop"
	"libvirt"
	"edk2-ovmf"
	"iptables-nft"
	"dmidecode"
)

bluetooth_packages=(
	"blueman"
	"bluez-utils"
)

mirror_packages=(
	"rate-mirrors-bin"
	"cachyos-rate-mirrors"
)

#-----------------------------
# Set GPU packages to install
#-----------------------------

if [[ $(get_primary_gpu) == "nvidia" ]]; then
	echo "Nvidia GPU drivers not yet implemented..."
	read -p "Press enter to continue"
elif [[ $(get_primary_gpu) == "amd" ]]; then
	gpu_packages=("mesa" "lib32-mesa" "vulkan-radeon" "lib32-vulkan-radeon" "vulkan-icd-loader" "lib32-vulkan-icd-loader" "libva-utils")
	sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf

elif [[ $(get_primary_gpu) == "intel" ]]; then
	gpu_packages=("mesa" "lib32-mesa" "vulkan-intel" "lib32-vulkan-intel" "intel-media-driver")
fi

if [[ $(get_primary_gpu) == "nvidia" || $(get_primary_gpu) == "amd" ]]; then
	clear

	# Inform the user about the pros and cons of using Mesa-Git
	printf "${GREEN}Upsides:${NC}\n"
	printf "  - Latest features, bug fixes, and performance improvements.\n"
	printf "  - Better compatibility with newer games and applications.\n\n"
	printf "${RED}Downsides:${NC}\n"
	printf "  - Potential instability and unexpected bugs.\n"
	printf "  - Possible regressions compared to stable versions.\n\n"
	
	# Prompt the user for confirmation
	printf "Do you want to use experimental mesa-git?"
	
	if confirm; then
		# Make sure the user understand the risks
		clear
		printf "${YELLOW}Warning:${NC} If you experience any problems, the first thing you should do is revert mesa-git to the stable version.\n\n"
		printf "Are you sure you want to use experimental mesa-git instead of the standard version?"
		
		if confirm; then
			gpu_packages=("mesa-git" "lib32-mesa-git")
		fi
	fi
fi

#-----------------------------

exclude_packages=(
    "tidal-hifi-bin"
	"prismlauncher"
	"curseforge"
    "piavpn-bin"
    "yay"
    "mullvad-vpn-bin"
    "cachyos.*"
    ".*.-ucode"
	
    ${mirror_packages[@]}
    ${kernel_packages[@]}
    ${prerequisites_packages[@]}
    ${packages[@]}
    ${android_development_packages[@]}
    ${virt_manager_packages[@]}
    ${bluetooth_packages[@]}
    ${obs_packages[@]}
    ${gpu_packages[@]}
)

# Get the list of explicitly installed packages, except for excluded packages
packages_to_remove=$(pacman -Qe | cut -d ' ' -f 1 | grep -v -E "^($(IFS='|'; echo "${exclude_packages[*]}"))$")

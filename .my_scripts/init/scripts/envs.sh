#!/bin/bash

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
    "discord"
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
    "firefox"
    "thunderbird"
)

kernel_packages=(
	"linux-zen"
	"linux"
	"linux-cachyos.*"
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

qBittorent_packages=(
	"qbittorrent"
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

nvidia_drivers () {
	echo "Nvidia GPU drivers not yet implemented..."
    read -p "Press enter to continue"	
}

amd_drivers () {
    gpu_packages=("mesa" "lib32-mesa" "vulkan-radeon" "lib32-vulkan-radeon" "vulkan-icd-loader" "lib32-vulkan-icd-loader" "libva-utils")
    sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf
}

intel_drivers () {
    gpu_packages=("mesa" "lib32-mesa" "vulkan-intel" "lib32-vulkan-intel" "intel-media-driver")
}

while true; do
    if [[ $(get_primary_gpu) == "nvidia" ]]; then
        nvidia_drivers
        break
    elif [[ $(get_primary_gpu) == "amd" ]]; then
        amd_drivers
        break
    elif [[ $(get_primary_gpu) == "intel" ]]; then
        intel_drivers
        break
    else
        # If get_primary_gpu doesn't exist or is invalid, manually choose the GPU
        clear
        echo -e "Script couldn't automatically detect GPU.\n"
        echo "Please manually choose your GPU:"
        echo "   1) Nvidia"
        echo "   2) AMD"
        echo -e "   3) Intel\n"
        read -p "Enter your choice (1/2/3): " gpu_choice

        case $gpu_choice in
            1)
                nvidia_drivers
                break
                ;;
            2)
                amd_drivers
                break
                ;;
            3)
                intel_drivers
                break
                ;;
            *)	
                ;;
        esac
    fi
done

#-----------------------------

exclude_packages=(
    "tidal-hifi-bin"
	"prismlauncher"
	"curseforge"
    "piavpn-bin"
    "yay"
    "mullvad-vpn-bin"
    "cachyos.*"
    "shadps4.*"
    ".*.-ucode"
	
    ${mirror_packages[@]}
    ${kernel_packages[@]}
    ${prerequisites_packages[@]}
    ${packages[@]}
    ${android_development_packages[@]}
    ${virt_manager_packages[@]}
    ${bluetooth_packages[@]}
    ${obs_packages[@]}
    ${qBittorent_packages[@]}
    ${gpu_packages[@]}
)

# Get the list of explicitly installed packages, except for excluded packages
packages_to_remove=$(pacman -Qe | cut -d ' ' -f 1 | grep -v -E "^($(IFS='|'; echo "${exclude_packages[*]}"))$")

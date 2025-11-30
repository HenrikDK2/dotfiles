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
    "fzf"

    # Makepkg related packages (Flags in ~/.makepkg.conf)
    "zstd"
    "pigz"
    "pbzip2"
    "xz"

    # Other
    "fuse2"
    "ntfs-3g"
    "7zip"
)

packages=(
    # Fonts
    "cantarell-fonts"
    "otf-font-awesome"
    "ttf-ms-fonts"
    "ttf-jetbrains-mono"
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
    "connman"
    "dnsmasq"
    "ufw"

    # Printer
    "cups"
    "ghostscript"
    "system-config-printer"
    "brlaser"
    "nss-mdns" # Avahi handling .local via mDNS
    
    # System
    "alacritty"
	"bash-completion"
	"blesh-git"
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
    "profile-sync-daemon"
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
    "localsend-bin"
    "firefox"
    "thunderbird"
)

kernel_packages=(
	"linux-zen.*"
	"linux.*"
	"linux-cachyos.*"
	"linux-lts.*"
	"linux-hardened.*"
	"linux-rt.*"
	"linux-rt-lts.*"
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

qbittorent_packages=(
	"qbittorrent"
)

obs_packages=(
	"obs-studio-browser"
	"obs-vkcapture"
)

virtualbox_packages=(
	"virtualbox"
	"virtualbox-host-dkms"
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
		clear_screen
    	
        # If get_primary_gpu doesn't exist or is invalid, manually choose the GPU
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

#-------------------------------
# Packages to keep on reinstall
#-------------------------------

exclude_packages=(
    "yay"

    "mullvad-vpn-bin"
    "piavpn-bin"
	"zerotier-one"
	
    "tidal-hifi-bin"
	"prismlauncher-git"
	"bolt-launcher"
	"curseforge"

	"gimp"
	"inkscape"
	"godot"
	"audacity"

    "amd-ucode"
    "intel-ucode"

	"dotnet-runtime"
	"dotnet-sdk"
	"aspnet-runtime"

    ${mirror_packages[@]}
    ${kernel_packages[@]}
    ${prerequisites_packages[@]}
    ${packages[@]}
    ${android_development_packages[@]}
    ${virtualbox_packages[@]}
    ${bluetooth_packages[@]}
    ${obs_packages[@]}
    ${qbittorent_packages[@]}
    ${gpu_packages[@]}
)

# Get the list of explicitly installed packages, except for excluded packages
packages_to_remove=$(pacman -Qe | cut -d ' ' -f 1 | grep -v -E "^($(IFS='|'; echo "${exclude_packages[*]}"))$")

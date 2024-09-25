#!/bin/bash

source $HOME/.my_scripts/init/scripts/functions.sh

packages=(
    # Fonts
    "cantarell-fonts"
    "otf-font-awesome"
    "ttf-jetbrains-mono"
    "ttf-ms-fonts"
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
    "btop"
    "cabextract"
    "cups"
    "dconf"
    "fish"
    "fisher"
    "fuse"
    "glib2"
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
    "discord"
    "wine"
    "gamemode"
    "gamescope"
    "heroic-games-launcher-bin"
    "lib32-gamemode"
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

# Install Android Development Tools
clear
printf "Do you want to install the required tools for android development?"

if confirm; then
	yay -S watchman-bin python jdk-openjdk android-tools android-studio --needed --noconfirm
fi

# Install Virt-manager
clear
printf "This is for virtual machines.\n\n"
printf "Do you want to install virt-manager?"

if confirm; then
    yay -S virt-manager qemu-desktop libvirt edk2-ovmf iptables-nft dmidecode --needed;
	sudo systemctl enable --now libvirtd virtlogd;
	sudo usermod -a -G libvirt $(whoami);
fi

# Setup bluetooth
clear
printf "This is for bluetooth.\n\n"
printf "Do you want to install blueman?"

if confirm; then
    sudo pacman -S blueman bluez-utils --needed --noconfirm;
    sudo systemctl enable --now bluetooth.service;
    echo 'power on' | bluetoothctl;
fi

# GPU drivers
clear
if [[ $(get_primary_gpu) == "nvidia" ]]; then
	echo "Nvidia GPU drivers not yet implemented..."
	read -p "Press enter to continue"
elif [[ $(get_primary_gpu) == "amd" ]]; then
	sudo pacman -S mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils --noconfirm
	sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf
	sudo mkinitcpio -P;
elif [[ $(get_primary_gpu) == "intel" ]]; then
	sudo pacman -S mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver --noconfirm
fi

# Install all packages
yay -S "${packages[@]}" --needed

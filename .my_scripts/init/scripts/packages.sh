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

# Ask if you want to install any of the optional packages
$HOME/.my_scripts/init/scripts/optional_packages.sh

# GPU drivers
clear
if [[ $(get_primary_gpu) == "nvidia" ]]; then
	echo "Nvidia GPU drivers not yet implemented..."
	read -p "Press enter to continue"
elif [[ $(get_primary_gpu) == "amd" ]]; then
	sudo pacman -S mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils
	sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf
elif [[ $(get_primary_gpu) == "intel" ]]; then
	sudo pacman -S mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver 
fi

# Install all packages
yay -S "${packages[@]}" --needed

# Enable required services
sudo systemctl enable cups ufw dnsmasq denyhosts fstrim.timer
systemctl --user enable wireplumber

# Mask unused services
systemctl --user mask at-spi-dbus-bus
sudo systemctl mask systemd-userdbd systemd-userdbd.socket accounts-daemon rtkit-daemon ldconfig upower systemd-resolved connman-vpn

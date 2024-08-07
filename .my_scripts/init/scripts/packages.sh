#!/bin/bash

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

# Install all packages
yay -S "${packages[@]}" --needed

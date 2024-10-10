#!/bin/bash

prerequisites_packages=(
    "linux-zen"
    "linux-firmware"

    "base"
    "base-devel"
    "mkinitcpio"

    "sudo"
    "git"
    "bc"
    "curl"
    "inetutils"
    "jq"
    "connman"

    # Makepkg related packages (Flags in ~/.makepkg.conf)
    "mold"
    "zstd"
    "pigz"
    "pbzip2"
    "xz"
)

# Packages to exclude from removal
exclude_packages=(
    "linux-tkg.*"
    "tidal-hifi-bin"
    "piavpn-bin"
    "yay"
    "mullvad-vpn-bin"
)

# Update package database and install prerequisites
sudo pacman -Syy ${prerequisites_packages[@]} --needed --noconfirm

# Create the exclusion pattern for grep
exclude_pattern=$(IFS="|"; echo "${prerequisites_packages[*]}|${exclude_packages[*]}")

# Get the list of explicitly installed packages, except for prerequisites and excluded packages
packages_to_remove=$(pacman -Qe | cut -d ' ' -f 1 | grep -v -E "^($exclude_pattern)$")

# Remove the unwanted packages, if any
if [ ! -z "$packages_to_remove" ]; then
    sudo pacman -Rns --nodeps --cascade $packages_to_remove --noconfirm
fi

# Enable connman
sudo systemctl enable --now connman

# Wait for internet connection
until ping -c 1 google.com &> /dev/null; do
    sleep 5
done

# Copy system files
sudo cp -r ~/.my_scripts/init/system/* /

# Add host to /etc/hosts file
echo 127.0.0.1 localhost $(hostname) | sudo tee /etc/hosts

# Enable multilib, DisableDownloadTimeout, and ParallelDownloads
if ! grep -q "DisableDownloadTimeout" "/etc/pacman.conf"; then
	sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
	sudo sed -i "/ParallelDownloads/c\ParallelDownloads = 10\nDisableDownloadTimeout" /etc/pacman.conf
	sudo pacman -Suuy
fi

# Install yay for AUR packages
if [ -z "$(pacman -Qe | grep yay)" ]; then
    # Loop until git clone succeeds
    while true; do
        git clone https://aur.archlinux.org/yay.git && break
        echo "Git clone failed. Retrying in 5 seconds..."
        sleep 5
    done

    sudo chmod 777 -R ./yay
    (cd yay && makepkg -si --noconfirm)
    rm -rf ./yay
fi

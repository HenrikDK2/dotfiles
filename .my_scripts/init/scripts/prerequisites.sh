#!/bin/bash

# Update package database and install prerequisites
sudo pacman -Syy ${prerequisites_packages[@]} --needed --ask 4

# Remove the unwanted packages, if any
if [ ! -z "$packages_to_remove" ]; then
    sudo pacman -Rns --nodeps --cascade $packages_to_remove --ask 4
fi

# Copy system files
sudo cp -r ~/.my_scripts/init/system/* /

# Add host to /etc/hosts file
echo 127.0.0.1 localhost $(cat /etc/hostname) | sudo tee /etc/hosts

# Enable connman
sudo systemctl enable connman
sudo systemctl start connman

# Wait for internet connection to the AUR
while true; do
    RESPONSE=$(curl --write-out "%{http_code}" --silent --output /dev/null "https://aur.archlinux.org")

    if [ "$RESPONSE" -eq 200 ]; then
        break
    else
        echo "Couldn't connect to AUR. Retrying in 5 seconds..."
        sleep 5
    fi
done

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

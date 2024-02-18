#!/bin/bash

# Make sure required packages are installed
yay -S rate-mirrors-bin cachyos-rate-mirrors --needed --noconfirm

# Run script to sort mirrors
sudo /usr/local/bin/mirrors.sh

# Updates the package databases and updates package to latest version
sudo pacman -Syyu --noconfirm

# Enable weekly timer
sudo systemctl enable mirrors.timer

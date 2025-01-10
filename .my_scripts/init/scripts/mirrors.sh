#!/bin/bash

# Make sure required packages are installed
yay -S "${mirror_packages[@]}" --ask 4

# Run script after short delay 
sudo /usr/local/bin/mirrors.sh

# Updates the package databases and updates package to latest version
sudo pacman -Syyu --ask 4

# Enable weekly timer
sudo systemctl enable mirrors.timer

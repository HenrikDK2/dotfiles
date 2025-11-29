#!/bin/bash

# Make sure required packages are installed
yay -S "${mirror_packages[@]}" --ask 4

# Check if the mirrors timer is active or has ever run
if ! systemctl is-enabled --quiet mirrors.timer 2>/dev/null && \
   ! systemctl list-timers --all | grep -q mirrors.timer; then
    sudo /usr/local/bin/mirrors.sh
fi

# Updates the package databases and updates package to latest version
sudo pacman -Syyu --ask 4

# Enable weekly timer
sudo systemctl enable mirrors.timer

#!/bin/bash

# Check if user has root permissions
if [[ $EUID -eq 0 ]]; then
   echo "You shouldn't run this script as root" 
   exit 1
fi

# Check if the user does not have full sudo privileges
if ! sudo -l 2>/dev/null | grep -q "(ALL : ALL) ALL"; then
    echo "User does not have full sudo privileges."
    exit 1
fi

# Check for an internet connection
if ! ping -c 1 google.com >/dev/null 2>&1; then
  echo "An internet connection is required to run this script."
  exit 1
fi

# Get access to certain functions required for the script to work
source $HOME/.my_scripts/init/scripts/functions.sh

# Prerequisites setup script to ensure all necessary dependencies are in place
$HOME/.my_scripts/init/scripts/prerequisites.sh

# Switch to CachyOS repository
$HOME/.my_scripts/init/scripts/cachyos-repo.sh

# Heroic games launcher config settings (Copies if config folders doesn't exist)
$HOME/.my_scripts/init/scripts/heroic.sh

# Enable custom mirror service for better download speeds
$HOME/.my_scripts/init/scripts/mirrors.sh

# Improve ext4 performance
$HOME/.my_scripts/init/scripts/ext4_optimizations.sh

# Avoid stalls on memory allocations
$HOME/.my_scripts/init/scripts/avoid_stalls_memory.sh

# Add bootloader entries
$HOME/.my_scripts/init/scripts/bootloader.sh

# Enable AMD overclocking service/script
$HOME/.my_scripts/init/scripts/amd_oc.sh

# Optimised Firefox/Thunderbird profile (Copies if config folders doesn't exist)
$HOME/.my_scripts/init/scripts/mozilla.sh

# Ultrawide gaps on workspace 1 (If aspect ratio is 32:9)
$HOME/.my_scripts/init/scripts/ultrawide_gaps.sh

# Install packages
$HOME/.my_scripts/init/scripts/packages.sh

# Setup UFW
$HOME/.my_scripts/init/scripts/firewall.sh

# Make user part of the games group (Allows proton to set niceness of process)
sudo usermod -a -G games $(whoami)

# Change default, and current user shell to fish
sudo chsh -s /bin/fish && sudo chsh -s /bin/fish $(whoami)

# Enable network time sync
sudo timedatectl set-ntp true

# Remove initial pacsave/pacnew files
sudo find /etc -name "*.pacnew" -o -name "*.pacsave" | xargs sudo rm;

# Reboot
for i in {5..1}; do echo "Rebooting in $i..."; sleep 1; done; reboot

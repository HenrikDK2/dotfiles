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

# Get access to certain functions/envs required for the script to work
source "$HOME/.my_scripts/init/scripts/functions.sh"
source "$HOME/.my_scripts/init/scripts/envs.sh"

echo "$packages_to_remove"

exit

# Prerequisites setup script to ensure all necessary dependencies are in place
source "$HOME/.my_scripts/init/scripts/prerequisites.sh"

# Switch to CachyOS repository
source "$HOME/.my_scripts/init/scripts/cachyos-repo.sh"

# Enable custom mirror service for better download speeds
source "$HOME/.my_scripts/init/scripts/mirrors.sh"

# Choice between linux-zen, or compile the kernel from source
source "$HOME/.my_scripts/init/scripts/kernel.sh"

# Add bootloader entries
source "$HOME/.my_scripts/init/scripts/bootloader.sh"

# Install packages
source "$HOME/.my_scripts/init/scripts/packages.sh"

# Heroic games launcher config settings (Copies if config folders doesn't exist)
source "$HOME/.my_scripts/init/scripts/heroic.sh"

# Improve ext4 performance
source "$HOME/.my_scripts/init/scripts/ext4_optimizations.sh"

# Avoid stalls on memory allocations
source "$HOME/.my_scripts/init/scripts/avoid_stalls_memory.sh"

# Enable AMD overclocking service/script
source "$HOME/.my_scripts/init/scripts/amd_oc.sh"

# Optimised Firefox/Thunderbird profile (Copies if config folders doesn't exist)
source "$HOME/.my_scripts/init/scripts/mozilla.sh"

# Ultrawide gaps on workspace 1 (If aspect ratio is 32:9)
source "$HOME/.my_scripts/init/scripts/ultrawide_gaps.sh"

# Setup UFW
source "$HOME/.my_scripts/init/scripts/firewall.sh"

# This will regenerate the initial ramdisk environment for all installed kernels
sudo mkinitcpio -P

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

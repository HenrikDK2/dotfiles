#!/bin/bash

# Check for an internet connection
if ! ping -c 1 google.com >/dev/null 2>&1; then
  echo "An internet connection is required to run this script."
  exit 1
fi

# If running as root, find a wheel user and re-run as them
if [[ $EUID -eq 0 ]]; then
	echo "Makes sure sudo is setup for rest of script"
    pacman -S awk sudo --needed --noconfirm
    sed -i 's/^#\s*\(%wheel ALL=(ALL:ALL) ALL\)/\1/' /etc/sudoers

    # Get first user in the wheel group
    echo "Script is running as root. Searching for a wheel user..."
    WHEEL_USER=$(getent group wheel | awk -F: '{print $4}' | cut -d, -f1)

    if [[ -z "$WHEEL_USER" ]]; then
        echo "No wheel users found. Add wheel group to your current user. 'usermod -aG wheel <username>' as ROOT"
        exit 1
    fi

    echo "Found wheel user: $WHEEL_USER"
    echo "Re-running script as $WHEEL_USER..."

    # Re-run script as wheel user and pass all arguments
    exec su - "$WHEEL_USER" -c "\"$0\" $*"
fi

# Check if the user does not have full sudo privileges
if ! sudo -l 2>/dev/null | grep -q "(ALL : ALL) ALL"; then
    echo "User does not have full sudo privileges."
    exit 1
fi

# Get access to certain functions/envs required for the script to work
source "$HOME/.my_scripts/init/scripts/functions.sh"
source "$HOME/.my_scripts/init/scripts/envs.sh"

# Prerequisites setup script to ensure all necessary dependencies are in place
source "$HOME/.my_scripts/init/scripts/prerequisites.sh"

# Switch to CachyOS repository
source "$HOME/.my_scripts/init/scripts/cachyos_repo.sh"

# Enable custom mirror service for better download speeds
source "$HOME/.my_scripts/init/scripts/mirrors.sh"

# Enable auto update service
source "$HOME/.my_scripts/init/scripts/auto_update.sh"

# Add bootloader entries, and install kernel
source "$HOME/.my_scripts/init/scripts/bootloader.sh"

# Install packages
source "$HOME/.my_scripts/init/scripts/packages.sh"

# ClamAV
source "$HOME/.my_scripts/init/scripts/clamav.sh"

# Setup autologin (Optional)
source "$HOME/.my_scripts/init/scripts/auto_login.sh"

# Heroic games launcher config settings (Copies if config folders doesn't exist)
source "$HOME/.my_scripts/init/scripts/heroic.sh"

# Improve ext4 performance, and improves v-fat security (boot)
source "$HOME/.my_scripts/init/scripts/drive_optimizations.sh"

# Enable AMD overclocking service/script
source "$HOME/.my_scripts/init/scripts/amd_oc.sh"

# Optimised Firefox/Thunderbird profile (Copies if config folders doesn't exist)
source "$HOME/.my_scripts/init/scripts/mozilla.sh"

# Install VSCode Extensions
source "$HOME/.my_scripts/init/scripts/code_extensions.sh"

# Setup UFW
source "$HOME/.my_scripts/init/scripts/firewall.sh"

# This will regenerate the initial ramdisk environment for all installed kernels
sudo mkinitcpio -P

# Make user part of the games group (Allows proton to set niceness of process)
sudo usermod -a -G games $(whoami)

# Enable network time sync
sudo timedatectl set-ntp true

# Remove initial pacsave/pacnew files
sudo find /etc -name "*.pacnew" -o -name "*.pacsave" | xargs sudo rm;

# Reboot
for i in {5..1}; do echo "Rebooting in $i..."; sleep 1; done; reboot

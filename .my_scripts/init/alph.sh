#!/bin/sh

# https://somegit.dev/ALHP/ALHP.GO 
# Adds x86-64-v3 repo if your system supports it.

if (/lib/ld-linux-x86-64.so.2 --help | grep -q "x86-64-v3 (supported, searched)"); then
	yay -S alhp-keyring alhp-mirrorlist --needed --noconfirm

    if (! grep -qE '^\[core-x86-64-v3\]$|^\[extra-x86-64-v3\]$|^\[multilib-x86-64-v3\]' /etc/pacman.conf); then
    	sudo sed -i '/^\[core\]/i [core-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n\n[extra-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n' /etc/pacman.conf
		sudo sed -i '/^\[multilib\]/i [multilib-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n' /etc/pacman.conf
    fi

	# Resolve potential issues with signatures
    sudo rm -rf /etc/pacman.d/gnupg/
    sudo pacman-key --init
    sudo pacman-key --populate

    # Update
    sudo pacman -Suuy
fi

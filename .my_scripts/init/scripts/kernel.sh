#!/bin/bash

# No need to re-compile the linux kernel, if linux-tkg is already installed
# Installs linux-zen, if the user doesn't want to compile the kernel

if ! pacman -Qq | grep -q "^linux-tkg$"; then
	clear
	printf "Do you want to compile an optimized kernel from source?"

	if confirm; then
		clear
		printf "The kernel will get updated via. update script on every two new PATCH versions \n\n"
		printf "Skips the first MINOR patch as it can be quite buggy\n\n"
		read -p "Press enter to continue"

		source "$HOME/.my_scripts/kernel.sh"
	else
		sudo pacman -S ${kernel_packages[0]} --needed --ask 4
	fi
fi

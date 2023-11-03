#!/bin/bash

function confirm() {
    while true; do
        read -p " [y/n] " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) printf "\nPlease answer YES or NO";;
        esac
    done
}

function get_primary_gpu() {
	local amd=$(lspci -vnn | grep VGA -A 12 | grep -i amdgpu)
	local intel=$(lspci -vnn | grep VGA -A 12 | grep -i Intel)
	local nvidia=$(lspci -vnn | grep VGA -A 12 | grep -i NVIDIA)

	if [ ! -z "$nvidia" ]; then
		echo "nvidia"
	elif [ ! -z "$amd" ]; then
		echo "amd"
	elif [ ! -z "$intel" ]; then
		echo "intel"
	fi

	exit 0
}

# GPU drivers
clear
if [[ $(get_primary_gpu) == "nvidia" ]]; then
	echo "Nvidia GPU drivers not yet implemented..."
	read -p "Press enter to continue"
elif [[ $(get_primary_gpu) == "amd" ]]; then
	sudo pacman -S mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils --noconfirm
	sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf
	sudo mkinitcpio -P;
elif [[ $(get_primary_gpu) == "intel" ]]; then
	sudo pacman -S lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver --noconfirm
fi

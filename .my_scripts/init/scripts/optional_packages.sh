#!/bin/bash

install_android_development_tools() {
	clear
	printf "Do you want to install the required tools for android development?"
	
	if confirm; then
		yay -S "${android_development_packages[@]}" --needed --noconfirm
		set_java_version 17
	fi
}

install_bluetooth() {
	clear
	printf "This is for bluetooth.\n\n"
	printf "Do you want to install blueman?"

	if confirm; then
	    yay -S "${bluetooth_packages[@]}" --needed --noconfirm
	    sudo systemctl enable --now bluetooth.service;
	    echo 'power on' | bluetoothctl;
	fi
}


install_virt_manager() {
	clear
	printf "This is for virtual machines.\n\n"
	printf "Do you want to install virt-manager?"

	if confirm; then
		yay -S "${virt_manager_packages[@]}" --needed --noconfirm
		sudo systemctl enable --now libvirtd virtlogd;
		sudo usermod -a -G libvirt $(whoami);
	fi
}

install_obs() {
	clear
	printf "This is for streaming/recording.\n\n"
	printf "Do you want to install obs-studio with browser source and game capture?"

	if confirm; then
		yay -S "${obs_packages[@]}" --needed --noconfirm
	fi
}

# Checks if any of the android packages are installed, if not
# then ask if you want to install Android Development Tools
for pkg in "${android_development_packages[@]}"; do
	if ! pacman -Q "$pkg" &> /dev/null; then
		install_android_development_tools
		break
	fi
done

# Checks if any of the android packages are installed, if not
# then ask if you want to install obs-studio packages
for pkg in "${obs_packages[@]}"; do
	if ! pacman -Q "$pkg" &> /dev/null; then
		install_obs
		break
	fi
done

# Checks if any of the virt manager packages are installed, if not
# then ask if you want to install Virt Manager
for pkg in "${virt_manager_packages[@]}"; do
	if ! pacman -Q "$pkg" &> /dev/null; then
		install_virt_manager
		break
	fi
done

# Checks if any of the bluetooth packages are installed, if not
# then ask if you want to install Bluetooth
for pkg in "${bluetooth_packages[@]}"; do
	if ! pacman -Q "$pkg" &> /dev/null; then
		install_bluetooth
		break
	fi
done

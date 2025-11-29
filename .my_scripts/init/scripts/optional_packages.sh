#!/bin/bash

install_android_development_tools() {
	clear_screen
	printf "Do you want to install the required tools for android development?"
	
	if confirm; then
		auto_install "${android_development_packages[@]}"
		set_java_version 17
	fi
}

install_qbittorrent() {
	clear_screen
	printf "Do you want to install qBittorent?"
	
	if confirm; then
		auto_install "${qbittorent_packages[@]}"
		cp -rf $HOME/.my_scripts/init/user/qBittorrent $HOME/.config
		sed -i "s/henrik/$USER/" $HOME/.config/qBittorrent/qBittorrent.conf
	fi
}

install_bluetooth() {
	clear_screen
	printf "This is for bluetooth.\n\n"
	printf "Do you want to install blueman?"

	if confirm; then
	    auto_install "${bluetooth_packages[@]}"
	    sudo systemctl enable --now bluetooth.service;
	    echo 'power on' | bluetoothctl;
	fi
}


install_virtualbox() {
	clear_screen
	printf "This is for virtual machines.\n\n"
	printf "Do you want to install VirtualBox?"

	if confirm; then
		auto_install "${virtualbox_packages[@]}"
		sudo usermod -a -G libvirt $(whoami);
	fi
}

install_obs() {
	clear_screen
	printf "This is for streaming/recording.\n\n"
	printf "Do you want to install obs-studio with browser source and game capture?"

	if confirm; then
		auto_install "${obs_packages[@]}"
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

# Checks if any of the VirtualBox packages are installed, if not
# then ask if you want to install VirtualBox
for pkg in "${virtualbox_packages[@]}"; do
	if ! pacman -Q "$pkg" &> /dev/null; then
		install_virtualbox
		sudo modprobe vboxdrv
		sudo /sbin/vboxconfig
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

# Checks if any of the qbittorrent packages are installed, if not
# then ask if you want to install qbittorrent
for pkg in "${qbittorent_packages[@]}"; do
	if ! pacman -Q "$pkg" &> /dev/null; then
		install_qbittorrent
		break
	fi
done

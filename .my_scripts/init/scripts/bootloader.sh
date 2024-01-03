#!/bin/bash

kernel_params=(
	# Reduce the attack surface of the system by reducing the amount of potentially sensitive information that is logged
	"loglevel=3"

	# Increase CPU performance, but might decrease battery life
	"processor.ignore_ppc=1"

	# Reduces overhead by disabling split-lock detection
	"split_lock_detect=off"

	# Improves boot times on harddrives
	"libahci.ignore_sss=1"

	# Reduce writes to SSD 
	"rootflags=noatime"

	# Disable watchdog to reduce overhead
	"nowatchdog"
	"nomce"
	"nmi_watchdog=0"
	"module_blacklist=iTCO_wdt"

	# Disable IPV6
	"ipv6.disable=1"

	# Disable amdgpu audio 
	"amdgpu.audio=0"

	# Enable AMD GPU overclocking
	"amdgpu.ppfeaturemask=0xffffffff"
)

kernel_params_str=$(printf "%s " "${kernel_params[@]}")

microcode () {
	if [ -n "$(cat /proc/cpuinfo | grep 'AuthenticAMD')" ]; then
		sudo pacman -S amd-ucode --noconfirm --needed
		sed -i '3 i initrd /amd-ucode.img' ~/.my_scripts/init/entries/tmp/*.conf
	elif [ -n "$(cat /proc/cpuinfo | grep 'GenuineIntel')" ]; then
		sudo pacman -S intel-ucode --noconfirm --needed
		sed -i '3 i initrd /intel-ucode.img' ~/.my_scripts/init/entries/tmp/*.conf
	fi
}

enable_hibernation () {
	sudo sed -i 's/^[ \t]*HOOKS=(base udev autodetect/HOOKS=(base udev resume autodetect/' /etc/mkinitcpio.conf
	sudo mkinitcpio -p linux-zen
}

add_options () {
	get_root_uuid (){
		clear
		printf 'Which partition is the root partition that Linux is running on? Example: sdc3\n\n'
		lsblk | grep /
		printf "\n"
		if [ -n "$1" ]; then printf "Couldn't find drive, try again!\n\n"; fi
		read ROOT_DRIVE
		ROOT_UUID=$(sudo blkid -o value -s UUID /dev/$ROOT_DRIVE)
		
		if [ -z $ROOT_UUID ]; then get_root_uuid "error"; fi
		sudo tune2fs -O fast_commit /dev/$ROOT_DRIVE
	}
	
	get_swap_uuid () {
		clear
		printf 'Which partition is the swap partition? Example: sdc2\n\n'
		printf "You can type \"none\", however hibernation will not be enabled\n\n"
		lsblk | grep SWAP
		printf "\n"
		if [ -n "$1" ]; then printf "Couldn't find drive, try again!\n\n"; fi
		read SWAP_DRIVE
		SWAP_UUID=$(sudo blkid -o value -s UUID /dev/$SWAP_DRIVE)
		
		if [[ -z $SWAP_UUID && "$SWAP_DRIVE" != "none" ]]; then get_swap_uuid "error"; fi
	}

	get_root_uuid
	if [ -n "$(lsblk | grep SWAP)" ]; then get_swap_uuid; fi

	if [[ -n $SWAP_UUID && -n $ROOT_UUID ]]; then
		echo "options root=UUID=$ROOT_UUID resume=UUID=$SWAP_UUID rw $kernel_params_str" | tee -a ~/.my_scripts/init/entries/tmp/*.conf
		enable_hibernation
	elif [[ -z $SWAP_UUID && -n $ROOT_UUID ]]; then
		echo "options root=UUID=$ROOT_UUID rw $kernel_params_str" | tee -a ~/.my_scripts/init/entries/tmp/*.conf
	fi
}

change_default () {
	if sudo grep "default" /boot/loader/loader.conf
	then
		sudo sed -i "s/default.*/default $1/" /boot/loader/loader.conf
	else
		echo "default $1" | sudo tee -a /boot/loader/loader.conf
	fi

	if sudo grep "timeout" /boot/loader/loader.conf
	then
		sudo sed -i 's/#timeout.*/timeout 3/' /boot/loader/loader.conf
	else
		echo "timeout 3" | sudo tee -a /boot/loader/loader.conf
	fi
}

# Install Linux Zen
if [ -z "$(pacman -Qe | grep 'linux-zen')" ]; then
	sudo pacman -Syu linux-zen --noconfirm --needed
	clear
fi

# Create temp kernel entries
mkdir ~/.my_scripts/init/entries/tmp
cp ~/.my_scripts/init/entries/*.conf ~/.my_scripts/init/entries/tmp
clear

# Add Intel or AMD microcode
microcode
clear

# Add options to kernel configuration files with tweaks
add_options

# Copy to boot
sudo cp -r ~/.my_scripts/init/entries/tmp/. /boot/loader/entries
rm -rf ~/.my_scripts/init/entries/tmp/

# Change default kernel to Linux Zen if run from install script
if [[ "${0}" =~ ".my_scripts/init/install.sh" ]]; then
    change_default zen.conf
    clear
fi

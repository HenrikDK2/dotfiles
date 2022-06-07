#!/bin/bash

sudo bootctl install
mkdir ~/.my-scripts/init/entries/tmp
cp ~/.my-scripts/init/entries/* ~/.my-scripts/init/entries/tmp

function microcode {
	echo 'Is this computer using "amd" or an "intel" cpu'
	read CPU
	
	if [ "$CPU" == "amd" ]; then
		sudo pacman -S amd-ucode
		sed -i '3 i initrd /amd-ucode.img' ~/.my-scripts/init/entries/tmp/tkg.conf
		sed -i '3 i initrd /amd-ucode.img' ~/.my-scripts/init/entries/tmp/arch.conf
	elif [ "$CPU" == "intel" ]; then
		sudo pacman -S intel-ucode
		sed -i '3 i initrd /intel-ucode.img' ~/.my-scripts/init/entries/tmp/tkg.conf
		sed -i '3 i initrd /intel-ucode.img' ~/.my-scripts/init/entries/tmp/arch.conf
	else
		echo "CPU needs to be either AMD or INTEL"
		microcode
	fi 
}

function get_uuid {
	lsblk
	echo 'Which partition is Linux running on? Example: sda1'
	read UUID
	fs_uuid=$(sudo blkid -o value -s UUID /dev/$UUID)
	if [ "$fs_uuid" == "" ]; then
		clear
		echo "Couldn't find drive, try again"
		get_uuid
	else
		sudo sed -i "s/#UUID/$fs_uuid/g" ~/.my-scripts/init/entries/tmp/tkg.conf
		sudo sed -i "s/#UUID/$fs_uuid/g" ~/.my-scripts/init/entries/tmp/arch.conf
	fi
}

clear
microcode
clear
get_uuid
sudo cp -r ~/.my-scripts/init/entries/tmp/. /boot/loader/entries
rm -rf ~/.my-scripts/init/entries/tmp/
clear


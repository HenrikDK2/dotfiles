#!/bin/bash

sudo bootctl install
sudo pacman -Syu linux-zen --noconfirm
mkdir ~/.my-scripts/init/entries/tmp
cp ~/.my-scripts/init/entries/* ~/.my-scripts/init/entries/tmp

function microcode {
	echo 'Is this computer using "amd" or an "intel" cpu'
	read CPU
	
	if [ "$CPU" == "amd" ]; then
		sudo pacman -S amd-ucode --noconfirm
		sed -i '3 i initrd /amd-ucode.img' ~/.my-scripts/init/entries/tmp/tkg.conf
		sed -i '3 i initrd /amd-ucode.img' ~/.my-scripts/init/entries/tmp/zen.conf
		sed -i '3 i initrd /amd-ucode.img' ~/.my-scripts/init/entries/tmp/arch.conf
	elif [ "$CPU" == "intel" ]; then
		sudo pacman -S intel-ucode --noconfirm
		sed -i '3 i initrd /intel-ucode.img' ~/.my-scripts/init/entries/tmp/tkg.conf
		sed -i '3 i initrd /intel-ucode.img' ~/.my-scripts/init/entries/tmp/zen.conf
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
		sudo sed -i "s/#UUID/$fs_uuid/g" ~/.my-scripts/init/entries/tmp/zen.conf
	fi
}

function change_default {
	if sudo grep -Rq "default" /boot/loader/loader.conf
	then
		sudo sed -i "s/default .*/default $1/" /boot/loader/loader.conf
	else
		echo "default $1" | sudo tee -a /boot/loader/loader.conf
	fi

	if sudo grep -Rq "timeout" /boot/loader/loader.conf
	then
		sudo sed -i "s/timeout .*/timeout 3/" /boot/loader/loader.conf
	else
		echo "timeout 3" | sudo tee -a /boot/loader/loader.conf
	fi
}

clear
microcode
clear
get_uuid
sudo cp -r ~/.my-scripts/init/entries/tmp/. /boot/loader/entries
rm -rf ~/.my-scripts/init/entries/tmp/
change_default arch.conf

clear
while true; do
	echo "Remember that you need to modify tkg.sh for your system."
    read -p "Do you wish to install the TKG-kernel? [y/n] " yn
    if [[ "$yn" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		change_default tkg.conf
		exec ~/.my-scripts/tkg.sh 
    elif [[ "$yn" =~ ^([nN])$ ]]; then
		sudo rm -rf /boot/loader/entries/tkg.conf
		clear
		read -p "Do you wish to make Zen the default kernel? [y/n] " yn
		if [[ "$yn" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			change_default zen.conf
		fi
		break;
    else
       echo "Please answer yes or no."
    fi
done
clear
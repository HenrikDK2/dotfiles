#!/bin/bash

sudo bootctl install
mkdir ~/.my-scripts/init/entries/tmp
cp ~/.my-scripts/init/entries/* ~/.my-scripts/init/entries/tmp

function microcode {
	echo 'Is this computer using "amd" or an "intel" cpu'
	read CPU
	
	if [ "$CPU" == "amd" ]; then
		sudo pacman -S amd-ucode --noconfirm
		sed -i '3 i initrd /amd-ucode.img' ~/.my-scripts/init/entries/tmp/tkg.conf
		sed -i '3 i initrd /amd-ucode.img' ~/.my-scripts/init/entries/tmp/arch.conf
	elif [ "$CPU" == "intel" ]; then
		sudo pacman -S intel-ucode --noconfirm
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
while true; do
	echo "Remember that you need to modify tkg.sh for your system."
    read -p "Do you wish to install the TKG-kernel now? [y/n] " yn
    if [[ "$yn" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		exec ~/.my-scripts/tkg.sh 
		clear
		read -p "Do you want to add TKG-kernel to the bootloader? [y/n] " yn
		if [[ "$yn" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			if sudo grep -Rq "default" /boot/loader/loader.conf
			then
				sudo sed -i "s/default .*/default tkg.conf/" /boot/loader/loader.conf
			else
				echo "default tkg.conf" | sudo tee -a /boot/loader/loader.conf
			fi
		fi
		break;
    elif [[ "$yn" =~ ^([nN])$ ]]; then
		break;
    else
       echo "Please answer yes or no."
    fi
done
clear


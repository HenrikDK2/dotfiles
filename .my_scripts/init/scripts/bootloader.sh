#!/bin/bash

kernel_params=(
	# Reduce the attack surface of the system by reducing the amount of potentially sensitive information that is logged
	"loglevel=3"

	# Disables the debugfs file system, which can be a potential attack vector for exploits
	"debugfs=off"

	# Disables the vDSO which can be a potential attack vector for exploits
	"vsyscall=none"

	# Increase CPU performance, but might decrease battery life
	"processor.ignore_ppc=1"

	# Reduces overhead by disabling split-lock detection
	"split_lock_detect=off"

	# Improves boot times on harddrives
	"libahci.ignore_sss=1"

	# Reduce writes to SSD 
	"rootflags=noatime"

	# Disable USB power management
	"usbcore.autosuspend=-1"

	# Stop rfkill from soft-blocking
	"rfkill.default_state=1"
	"rfkill.master_switch_mode=2"

	# Enable MSI to reduce latency
	"amdgpu.msi=1"
	"nvidia.NVreg_EnableMSI=1"

	# Disable watchdog to reduce overhead
	"nowatchdog"
	"nmi_watchdog=0"
	"module_blacklist=iTCO_wdt"

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
}

add_options () {
	get_root_uuid (){
		ROOT_DRIVE=$(df -hT / | awk 'NR==2 {print $1}')
		ROOT_UUID=$(sudo blkid -o value -s UUID $ROOT_DRIVE)
		sudo tune2fs -O fast_commit $ROOT_DRIVE
	}
	
	get_swap_uuid () {
		SWAP_DRIVE=$(swapon --show=NAME --noheadings --raw | awk '{print $1}')
		SWAP_UUID=$(sudo blkid -o value -s UUID $SWAP_DRIVE)
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

# Install systemd-boot
if [ ! -d "/boot/loader" ]; then
    sudo bootctl install
fi

# Loader config
echo "timeout 3" | sudo tee "/boot/loader/loader.conf" > /dev/null

# Check for installed kernel packages and append the default kernel entry to the loader config
if pacman -Qq | grep -q "^linux-tkg$"; then
    echo "default tkg.conf" | sudo tee -a "/boot/loader/loader.conf" > /dev/null
elif pacman -Qq | grep -q "^linux-zen$"; then
    echo "default zen.conf" | sudo tee -a "/boot/loader/loader.conf" > /dev/null
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

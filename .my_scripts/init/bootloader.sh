#!/bin/bash

kernel_hardening=(
	# Disables the vDSO which can be a potential attack vector for exploits
	"vsyscall=none"

	# Randomizes the kernel stack offset for each task, making it more difficult for attackers to locate and exploit stack buffer overflows
	"randomize_kstack_offset=on"

	# Prevent certain types of attacks that target the kernel memory allocation subsystem
	"slab_nomerge"

	# Disables IPv6, it can help reduce attack surface
	"ipv6.disable=1"

	# Prevent the loading of malicious or unsigned modules that could be used to exploit the system
	"modules.sig_enforce=1"

	# Prevent certain types of attacks that rely on uninitialized memory
	"init_on_alloc=1"

	# Prevent certain types of attacks that rely on accessing freed memory
	"init_on_free=1"

	# Shuffles the allocation of physical pages by the kernel, making it more difficult for attackers to predict the physical layout of memory
	"page_alloc.shuffle=1"

	# Disables the debugfs file system, which can be a potential attack vector for exploits
	"debugfs=off"

	# This can help improve performance and reduce the attack surface of the system by reducing the amount of potentially sensitive information that is logged
	"loglevel=3"

	# Protect against the Meltdown CPU vulnerability by isolating kernel memory from user processes
	"pti=on" 
)

kernel_other=(
	# Fixes Hogwarts Legacy crashing issue (Might resolve other games)
	"clearcpuid=514" 
	
	# Reduces latency
	"preempt=full" 
	
	# Disabling MCEs can help improve system stability and prevent potential data loss
	"mce=0"
	
	# Improve clock_gettime throughput (~50 times higher than other options)
	"tsc=reliable" 
	"clocksource=tsc"

	# Improves boot times on harddrives
	"libahci.ignore_sss=1"

	# Disable watchdog to reduce overhead
	"nowatchdog"
	"nmi_watchdog=0"
	"module_blacklist=iTCO_wdt"

	# Increase CPU performance, but might decrease battery life
	"processor.ignore_ppc=1"

	# Reduces overhead by disabling split-lock detection
	"split_lock_detect=off"

	# Enable AMD GPU overclocking
	"amdgpu.ppfeaturemask=0xffffffff"
)

kernel_params_str=$(printf "%s " "${kernel_hardening[@]}" "${kernel_other[@]}")

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

# Change default kernel to Linux Zen
change_default zen.conf
clear

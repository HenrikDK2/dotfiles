#!/bin/bash

kernel_hardening="slab_nomerge init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 debugfs=off kernel.yama.ptrace_scope=3 kernel.perf_event_paranoid=3 kernel.unprivileged_userns_clone=0 kernel.kexec_load_disabled=1 vm.unprivileged_userfaultfd=0 dev.tty.ldisc_autoload=0 kernel.unprivileged_bpf_disabled=1 net.core.bpf_jit_harden=2 kernel.kptr_restrict=2 kernel.dmesg_restrict=1"
kernel_params="$kernel_hardening nowatchdog nmi_watchdog=0 split_lock_detect=off amdgpu.ppfeaturemask=0xffffffff module_blacklist=iTCO_wdt loglevel=3"

function microcode {
	echo 'Is this computer using "amd" or an "intel" cpu'
	read CPU
	
	if [ "$CPU" == "amd" ]; then
		sudo pacman -S amd-ucode --noconfirm
		sed -i '3 i initrd /amd-ucode.img' ~/.my_scripts/init/entries/tmp/*.conf
	elif [ "$CPU" == "intel" ]; then
		sudo pacman -S intel-ucode --noconfirm
		sed -i '3 i initrd /intel-ucode.img' ~/.my_scripts/init/entries/tmp/*.conf
	else
		echo "CPU needs to be either AMD or INTEL"
		microcode
	fi 
}

function add_options {
	lsblk
	echo 'Which partition is the root partition that Linux is running on? Example: sdc3'
	read UUID
	fs_uuid=$(sudo blkid -o value -s UUID /dev/$UUID)
	if [ "$fs_uuid" == "" ]; then
		clear
		echo "Couldn't find drive, try again"
		get_uuid
	else
		echo "options root=UUID=$fs_uuid rw $kernel_params" | tee -a ~/.my_scripts/init/entries/tmp/*.conf
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

# Install Linux Zen
sudo pacman -Syu linux-zen --noconfirm
clear

# Create temp kernel entries
mkdir ~/.my_scripts/init/entries/tmp
cp ~/.my_scripts/init/entries/* ~/.my_scripts/init/entries/tmp
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

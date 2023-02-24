#!/bin/bash

kernel_hardening_net="net.ipv4.tcp_syncookies=1 net.ipv4.tcp_rfc1337=1 net.ipv4.conf.all.rp_filter=1 net.ipv4.conf.default.rp_filter=1 net.ipv4.conf.all.accept_redirects=0 net.ipv4.conf.default.accept_redirects=0 net.ipv4.conf.all.secure_redirects=0 net.ipv4.conf.default.secure_redirects=0 net.ipv6.conf.all.accept_redirects=0 net.ipv6.conf.default.accept_redirects=0 net.ipv4.conf.all.send_redirects=0 net.ipv4.conf.default.send_redirects=0 net.ipv4.icmp_echo_ignore_all=1 net.ipv4.conf.all.accept_source_route=0 net.ipv4.conf.default.accept_source_route=0 net.ipv6.conf.all.accept_source_route=0 net.ipv6.conf.default.accept_source_route=0 net.ipv6.conf.all.accept_ra=0 net.ipv6.conf.default.accept_ra=0 net.ipv4.tcp_sack=0 net.ipv4.tcp_dsack=0 net.ipv4.tcp_fack=0"
kernel_hardening="$kernel_hardening_net vsyscall=none randomize_kstack_offset=on slab_nomerge init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 debugfs=off kernel.yama.ptrace_scope=3 kernel.perf_event_paranoid=3 kernel.unprivileged_userns_clone=0 kernel.kexec_load_disabled=1 kernel.sysrq=4 vm.unprivileged_userfaultfd=0 dev.tty.ldisc_autoload=0 kernel.unprivileged_bpf_disabled=1 net.core.bpf_jit_harden=2 kernel.kptr_restrict=2 kernel.dmesg_restrict=1 loglevel=3"
if [ "$(uname -m)" == "x86_64" ]; then kernel_hardening="$kernel_hardening vm.mmap_rnd_bits=32 vm.mmap_rnd_compat_bits=16"; fi
kernel_params="$kernel_hardening clearcpuid=514 pti=on preempt=full tsc=reliable clocksource=tsc libahci.ignore_sss=1 nowatchdog nmi_watchdog=0 module_blacklist=iTCO_wdt processor.ignore_ppc=1 split_lock_detect=off amdgpu.ppfeaturemask=0xffffffff"

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
		echo "options root=UUID=$ROOT_UUID resume=UUID=$SWAP_UUID rw $kernel_params" | tee -a ~/.my_scripts/init/entries/tmp/*.conf
		enable_hibernation
	elif [[ -z $SWAP_UUID && -n $ROOT_UUID ]]; then
		echo "options root=UUID=$ROOT_UUID rw $kernel_params" | tee -a ~/.my_scripts/init/entries/tmp/*.conf
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

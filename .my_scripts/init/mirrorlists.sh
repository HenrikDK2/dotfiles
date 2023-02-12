#!/bin/sh

V3="$(/lib/ld-linux-x86-64.so.2 --help | grep supported | grep "x86-64-v3")"
V4="$(/lib/ld-linux-x86-64.so.2 --help | grep supported | grep "x86-64-v4")"

# If x86-64-v3 is supported by the CPU (https://git.harting.dev/ALHP/ALHP.GO)
if [ -z "$(grep -F '[core-x86-64-v3]' /etc/pacman.conf)" ] && [ -n "$V3" ]; then
	yay -Syu alhp-keyring alhp-mirrorlist --noconfirm
	sudo sed -i '/\[core\]/i[core-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n\n[extra-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n\n[community-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n' /etc/pacman.conf
fi

# Use cachyos-v4 mirrorlist, if x86-64-v4 is supported by the CPU
if [ -z "$(grep -F '[cachyos-v4]' /etc/pacman.conf)" ] && [ -n "$V4" ]; then
    sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key F3B607488DB35A47
    sudo pacman -U 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-3-1-any.pkg.tar.zst' --noconfirm
	sudo sed -i '/\[core-x86-64-v3]/i [cachyos-v4]\nInclude = /etc/pacman.d/cachyos-v4-mirrorlist\n' /etc/pacman.conf
fi

# Find the fastest mirrors
if [ -z "$(pacman -Qe | grep reflector)" ]; then
    sudo pacman -S reflector --noconfirm --needed
    sudo reflector --verbose -l 30 -n 5 --sort rate -p https --connection-timeout 3 --download-timeout 3 --save /etc/pacman.d/mirrorlist
fi

sudo pacman -Suy
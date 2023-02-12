#!/bin/sh

V3="$(/lib/ld-linux-x86-64.so.2 --help | grep supported | grep "x86-64-v3")"

sudo pacman -S wget --noconfirm

wget https://mirror.cachyos.org/cachyos-repo.tar.xz
(tar xvf cachyos-repo.tar.xz && cd cachyos-repo && sudo ./cachyos-repo.sh)
rm -rf cachyos-*

# If x86-64-v3 is supported by the CPU (https://git.harting.dev/ALHP/ALHP.GO)
if [ -z "$(grep -F '[core-x86-64-v3]' /etc/pacman.conf)" ] && [ -n "$V3" ]; then
	yay -Syu alhp-keyring alhp-mirrorlist --noconfirm
	sudo sed -i '/\[core\]/i[core-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n\n[extra-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n\n[community-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n' /etc/pacman.conf
fi

# Find the fastest mirrors
if [ -z "$(pacman -Qe | grep reflector)" ]; then
    sudo pacman -S reflector --noconfirm --needed
    sudo reflector --verbose -l 30 -n 5 --sort rate -p https --connection-timeout 3 --download-timeout 3 --save /etc/pacman.d/mirrorlist
fi

sudo pacman -Suuy --noconfirm

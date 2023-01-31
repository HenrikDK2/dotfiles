#!/bin/sh

# Use ALHP mirror if supported by the CPU (https://git.harting.dev/ALHP/ALHP.GO)
if [ -z "$(grep -F '[core-x86-64-v3]' /etc/pacman.conf)" ] && [ -n "$(lscpu | grep 'sse4_2')" ]; then
	yay -S alhp-keyring alhp-mirrorlist --noconfirm --needed
	sudo sed -i '/\[core\]/i [core-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n\n[extra-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n\n[community-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n' /etc/pacman.conf
	sudo pacman -Suy --noconfirm
fi

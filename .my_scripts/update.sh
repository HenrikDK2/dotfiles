#!/bin/sh

clear
sudo pacman -Sy
clear

# Run pacman update check
updates_available=$(pacman -Qu --check)

# Check if there are updates available
if [ -n "$updates_available" ]; then
	yay -Syu --noconfirm --needed

	while ! [ "$(pacman -Qdtq)" = "" ]; do
		sudo pacman -Rsunc $(pacman -Qdtq) --noconfirm
	done

	sudo yay -Scc --noconfirm --needed

	# Audit
	echo -e "\n\033[1mBeginning audit.\033[0m\n"
	~/.my_scripts/audit.sh
else
	echo "No updates available"
fi

#!/bin/sh

clear
sudo pacman -Sy
clear

# Run pacman update check
updates_available=$(pacman -Qu --check)

# Check if there are updates available
if [ -n "$updates_available" ]; then
	# Updating
	echo -e "\033[1mUpdating packages.\033[0m\n"
	yay -Su --noconfirm --needed

	# Cleanup
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
	echo -e "\033[1mClean up.\033[0m\n"
	while ! [ "$(pacman -Qdtq)" = "" ]; do
		sudo pacman -Rsunc $(pacman -Qdtq) --noconfirm
	done

	sudo yay -Scc --noconfirm --needed

	# Audit
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
	echo -e "\033[1mBeginning audit.\033[0m\n"
	~/.my_scripts/audit.sh
else
	echo "No updates available"
fi

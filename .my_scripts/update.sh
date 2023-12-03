#!/bin/sh

GITFLAGS="--filter=tree:0"

audit(){
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
	echo -e "\033[1mBeginning audit.\033[0m\n"
	~/.my_scripts/audit.sh
}

update_packages(){
	# Update normal packages
	echo -e "\033[1mUpdating packages.\033[0m\n"
	yay -Syu --devel --noconfirm

	# Update flatpak packages
	if command -v flatpak &> /dev/null; then
	  sudo flatpak update --noninteractive
	fi

	# Update kernel
	if [ -d ~/.cache/linux-tkg ]; then
		local stable_kernel=$(curl -s https://www.kernel.org/finger_banner | grep -oP -m1 '\K\d+\.\d+\.\d+')
		local current_kernel=$(uname -r | cut -d'-' -f1)
		
		if [[ "$stable_kernel" != "$current_kernel" ]]; then
			~/.my_scripts/kernel.sh
		fi
	fi
}

# Check for an internet connection
if ! ping -c 1 google.com >/dev/null 2>&1; then
  echo "An internet connection is required to run this script."
  exit 1
fi

# Sync DB
sudo pacman -Sy

# Reduce priority of script
renice -n 20 -p $$ -g $$
ionice -c 3 -p $$ -P $$
clear

# Check if there are updates available
if [ -n "$(pacman -Qu --check)" ] || [ ! -f ~/.cache/git-update-last ]; then
	update_packages
	audit
else
	echo "No updates available"
fi

printf "\n"
read -p "Press enter to continue"
exit 0

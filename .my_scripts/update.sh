#!/bin/sh

GITFLAGS="--filter=tree:0"

audit(){
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
	echo -e "\033[1mBeginning audit.\033[0m\n"
	~/.my_scripts/audit.sh
}

update_normal_packages() {
	echo -e "\033[1mUpdating packages.\033[0m\n"
	output=$(yay -Syu --noconfirm 2>&1 | tee /dev/tty)

	# Check if mirror failed
	if echo "$output" | grep -q "error: failed retrieving file"; then
	    echo -e "Error detected\n"

	    echo -e "Trying to fix issue by refreshing mirrorlists\n"
	    sudo /usr/local/bin/mirrors.sh

		clear
		echo -e "\033[1mUpdating packages.\033[0m\n"
		yay -Syu --noconfirm
	fi
}

update_kernel(){
	if pacman -Qi "linux-tkg" &> /dev/null; then
		local stable_kernel=$(pacman -Si linux | grep Version | awk '{print $3}' | cut -d'.' -f1-3)
		local current_kernel=$(pacman -Qi linux-tkg | awk '/^Version/ {print $3}' | cut -d'-' -f1)
		
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

# Reduce priority of script
renice -n 20 -p $$ -g $$ > /dev/null
ionice -c 3 -P $$ > /dev/null

# Update packages
update_normal_packages

# Update flatpak packages
if command -v flatpak &> /dev/null; then
  sudo flatpak update --noninteractive
fi

# Update custom built kernel
update_kernel

# Update wine-ge-custom
$HOME/.my_scripts/wine-ge-custom.sh

# Clear files stored in memory
if [ "$(ls /tmp)" ]; then
	sudo rm -r /tmp/*
fi

# Check for any systemd/journald issues
audit

printf "\n"
read -p "Press enter to continue"

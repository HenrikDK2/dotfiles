#!/bin/sh

clear
sudo pacman -Sy
clear

# Run pacman update check
updates_available=$(pacman -Qu --check)

# Check if there are updates available
if [ -z "$updates_available" ]; then
	## Reduce priority of script
	renice 20 $$
	ionice -c 3 -p $$
	clear

	# Updating normal packages
	echo -e "\033[1mUpdating packages.\033[0m\n"
	yay -Su --noconfirm --needed

	# Update -git AUR packages (Weekly)
	last_update_seconds=$(cat ~/.cache/git-update-last)
	current_time_seconds=$(date +%s)
	week_in_seconds=604800  # Number of seconds in a week

	# Check if the last update timestamp exists and if it's been a week since the last update
	if [ -z "$last_update_seconds" ] || ((current_time_seconds - last_update_seconds >= week_in_seconds)); then
	    yay -Syu --devel --noconfirm --needed
	    echo "$(date +%s)" > ~/.cache/git-update-last
	fi
	
	# Cleanup
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
	echo -e "\033[1mClean up.\033[0m\n"
	while ! [ "$(pacman -Qdtq)" = "" ]; do
		sudo pacman -Rsunc $(pacman -Qdtq) --noconfirm
	done

	yay -Scc --noconfirm --needed

	# Audit
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
	echo -e "\033[1mBeginning audit.\033[0m\n"
	~/.my_scripts/audit.sh
else
	echo "No updates available"
fi

printf "\n"
read -p "Press enter to continue"


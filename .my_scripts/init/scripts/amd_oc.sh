#!/bin/bash

original_conf_file="$HOME/.my_scripts/init/system/etc/amd-overclock.original"
conf_file="/etc/amd-overclock.conf"

if [ "$(get_primary_gpu)" = "amd" ] && ! systemctl is-enabled amd-overclock >/dev/null 2>&1; then
	clear_screen
	printf "Do you want to enable AMD overclocking via. system service?"

	if confirm; then
		sudo cp -f $original_conf_file $conf_file
	
		# Comment out each variable in the config file
		sudo sed -i 's/^\(VOLTAGE_OFFSET=.*\)/#\1/' "$conf_file"
		sudo sed -i 's/^\(CORE_CLOCK=.*\)/#\1/' "$conf_file"
		sudo sed -i 's/^\(MEMORY_CLOCK=.*\)/#\1/' "$conf_file"
		sudo sed -i 's/^\(MAX_WATTS_POWERLIMIT=.*\)/#\1/' "$conf_file"

		clear_screen
		printf "Overclock values will be commented out by default.\n\n"
		printf "You will need to modify ${yellow}$conf_file${reset}"

		printf "\n\n"
		read -p "Press enter to continue"

		# Edit config file 
		sudo pacman -Syu micro --noconfirm --needed
		sudo micro $conf_file

		# Enable service
		sudo systemctl enable amd-overclock.service
	fi
fi

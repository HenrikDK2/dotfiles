#!/bin/bash

source $HOME/.my_scripts/init/scripts/functions.sh

# ANSI escape codes for yellow color
yellow='\033[1;33m'
reset='\033[0m' # reset to default color
conf_file="/etc/amd-overclock.conf"

if [ "$(get_primary_gpu)" = "amd" ] && ! systemctl is-enabled amd-overclock >/dev/null 2>&1; then
 	clear
	printf "Do you want to enable AMD overclocking via. system service?"

	if confirm; then
		# Comment out each variable in the config file
		sudo sed -i 's/^\(VOLTAGE_OFFSET=.*\)/#\1/' "$conf_file"
		sudo sed -i 's/^\(CORE_CLOCK=.*\)/#\1/' "$conf_file"
		sudo sed -i 's/^\(MEMORY_CLOCK=.*\)/#\1/' "$conf_file"
		sudo sed -i 's/^\(MAX_WATTS_POWERLIMIT=.*\)/#\1/' "$conf_file"
		clear
		
		printf "Overclock values will be commented by default.\n\n"
		printf "You will need to modify ${yellow}$conf_file${reset}"

		printf "\n\n"
		read -p "Press enter to continue"

		sudo xdg-open $conf_file
		sudo systemctl enable amd-overclock.service
	fi
fi

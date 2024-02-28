#!/bin/bash

source $HOME/.my_scripts/init/scripts/functions.sh
oc_dir="$HOME/.my_scripts/init/amd_oc"

# ANSI escape codes for yellow color
yellow='\033[1;33m'
reset='\033[0m' # reset to default color

script="$oc_dir/oc.sh"
service="$oc_dir/amd-overclock.service"

script_dest="/usr/local/bin/oc.sh"
service_dest="/etc/systemd/system/amd-overclock.service"

if [  $(get_primary_gpu) = "amd" ] && [ ! -f "$script_dest" ]; then
	clear
	printf "Do you want to enable AMD overclocking via. system file/service?\n\n"
	printf "${yellow}$script_dest${reset} echo values will be commented by default.\n"
	printf "You will need to modify ${yellow}$script_dest${reset} for values that work with your GPU?"

	if confirm; then
		sudo cp "$script" "$script_dest"
		sudo cp "$service" "$service_dest"
		sudo systemctl enable amd-overclock.service

		while IFS= read -r line; do
			if [[ $line == "echo"* ]]; then
		    	sudo sed -i 's/^echo/#echo/' "$script_dest"
		    	break
		 	fi
		done < "$script_dest"
	fi
fi

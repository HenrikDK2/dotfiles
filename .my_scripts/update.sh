#!/bin/sh

source $HOME/.my_scripts/init/scripts/functions.sh

GITFLAGS="--filter=tree:0"

audit(){
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
	echo -e "\033[1mBeginning audit.\033[0m\n"
	~/.my_scripts/audit.sh
}

update_flatpak () {
	if command -v flatpak &> /dev/null; then
	  sudo flatpak update --noninteractive
	fi
}

update_normal_packages() {
	echo -e "\033[1mUpdating packages.\033[0m\n"
	output=$(yay -Syu --noconfirm 2>&1 | tee /dev/tty)

	# Check if mirror failed
	if [[ "$output" == *"error: failed to synchronize all databases"* || "$output" == *"error: failed retrieving file"* ]]; then
		clear
	    echo -e "Error with mirrorlists detected\n"

	    echo -e "Trying to fix issue by refreshing mirrorlists\n"
	    sudo /usr/local/bin/mirrors.sh

		clear
		echo -e "\033[1mUpdating packages.\033[0m\n"
		yay -Syu --noconfirm
	fi
}

update_kernel(){
    if pacman -Qi "linux-tkg" &> /dev/null; then
        local stable_kernel=$(get_stable_kernel)
        local current_kernel=$(pacman -Qi linux-tkg | awk '/^Version/ {print $3}' | cut -d'-' -f1)
        
        # Extract major, minor, and patch versions
        local stable_major=$(echo "$stable_kernel" | cut -d'.' -f1)
        local stable_minor=$(echo "$stable_kernel" | cut -d'.' -f2)
        local stable_patch=$(echo "$stable_kernel" | cut -d'.' -f3)

        local current_major=$(echo "$current_kernel" | cut -d'.' -f1)
        local current_minor=$(echo "$current_kernel" | cut -d'.' -f2)
        local current_patch=$(echo "$current_kernel" | cut -d'.' -f3)

        # Precompute the minimum required patch
        local minimum_req_patch=$((current_patch + 2))
	
	    # Check if the kernel should be updated:
	    if [[ "$stable_patch" -ne 0 && (  # Ensure stable patch version is not 0
	        # 1. If the stable kernel has a different major or minor version than the current kernel, update
	        "$stable_major" -ne "$current_major" || 
	        "$stable_minor" -ne "$current_minor" || 
	        # 2. If the stable kernel has the same major and minor versions, ensure the patch version is at least 2 higher
	        ("$stable_patch" -ge 1 && "$stable_patch" -ge "$minimum_req_patch")
	    ) ]]; then
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

update_normal_packages
update_flatpak
update_kernel
audit

printf "\n"
read -p "Press enter to continue"

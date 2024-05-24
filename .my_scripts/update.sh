#!/bin/sh

GITFLAGS="--filter=tree:0"

audit(){
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
	echo -e "\033[1mBeginning audit.\033[0m\n"
	~/.my_scripts/audit.sh
}

get_stable_kernel(){
	local stable_kernel=$(curl -s https://www.kernel.org/finger_banner | grep -oP 'The latest stable version of the Linux kernel is:\s+\K[\d.]+')

	if [[ $stable_kernel == *.* && $stable_kernel != *.*.* ]]; then
	    stable_kernel="${stable_kernel}.0"
	fi

	echo "$stable_kernel"
}

update_normal_packages() {
	echo -e "\033[1mUpdating packages.\033[0m\n"
	output=$(yay -Syu --noconfirm 2>&1 | tee /dev/tty)

	# Check if mirror failed
	if echo "$output" | grep -q "error: failed retrieving file"; then
	    echo -e "Error detected\n"

	    echo -e "Trying to fix issue by refreshing mirrorlists\n"
	    sudo /usr/local/bin/mirrors.sh
		
	    yay -Syu --noconfirm
	fi
}

update_packages(){
	# Update normal packages
	update_normal_packages

	# Update flatpak packages
	if command -v flatpak &> /dev/null; then
	  sudo flatpak update --noninteractive
	fi

	# Update kernel
	if pacman -Qi "linux-tkg" &> /dev/null; then
		local stable_kernel=$(get_stable_kernel)
		local current_kernel=$(pacman -Qi linux-tkg | awk '/^Version/ {print $3}' | cut -d'-' -f1)
		
		if [[ "$stable_kernel" != "$current_kernel" ]]; then
			~/.my_scripts/kernel.sh
		fi
	fi

	# Update wine-ge-custom
	$HOME/.my_scripts/wine-ge-custom.sh
}

# Check for an internet connection
if ! ping -c 1 google.com >/dev/null 2>&1; then
  echo "An internet connection is required to run this script."
  exit 1
fi

# Sync DB
sudo pacman -Sy > /dev/null

# Reduce priority of script
renice -n 20 -p $$ -g $$ > /dev/null
ionice -c 3 -P $$ > /dev/null

# Check if there are updates available
if [ -n "$(pacman -Qu --check)" ]; then
	clear
	update_packages
	audit
else
	clear
	echo "No updates available"
fi

printf "\n"
read -p "Press enter to continue"
exit 0

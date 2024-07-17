#!/bin/bash

source $HOME/.my_scripts/init/scripts/functions.sh

db_file=~/.config/modprobed.db
kernel_folder=~/.cache/linux-tkg
config_file=$kernel_folder/customization.cfg
stable_kernel=$(get_stable_kernel)

set_config(){
    awk -v key="$1" -v value="$2" 'BEGIN{FS=OFS="="} $1 == key {$2 = "\"" value "\""} 1' "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
}

install_latest_kernel(){
	cd $kernel_folder
	git restore .
	git pull --force

	# Modify package name to 'linux-tkg'
	set_config "_custom_pkgbase" "linux-tkg"

	# Change kernel version to stable
	set_config "_version" "$stable_kernel"

    # Set CPU scheduler to 'eevdf'
	set_config "_cpusched" "eevdf"

	# Reduce overhead by lowering max cpu cores to current processor cores (Requires recompile on new CPU)
	set_config "_NR_CPUS_value" "$(nproc)"
	
	# Enable compiler optimizations (-O3)
	set_config "_compileroptlevel" "2"

	# Enable modprobeddb
	set_config "_modprobeddb" "true"

	# Tickless idle
	set_config "_tickless" "2"

	# Set timer frequency to 1000
	set_config "_timer_freq" "1000"

	# Disable ftrace
	set_config "_ftracedisable" "true"

	# Disable debugging
	set_config "_debugdisable" "true"

	# Enable ACS override
	set_config "_acs_override" "false"

	# Disable Android modules for Waydroid
	set_config "_waydroid" "false"

	# Disable menuconfig
	set_config "_menunconfig" "0"

	# Enable full LTO and use the LLVM compiler
	set_config "_lto_mode" "full"

	# Switched to gcc until llvm problem is fixed: (https://gitlab.archlinux.org/archlinux/packaging/packages/pahole/-/issues/1)
	set_config "_compiler" "gcc"

	# Force the use of the LLVM Integrated Assembler
	set_config "_llvm_ias" "1"

	# Compile for the native CPU architecture
	local model_name=$(lscpu | grep "Model name")
	local vendor_id=$(lscpu | awk '/Vendor ID:/ {print $3}')

	if [[ $model_name =~ "Ryzen 7 5800X3D" ]]; then
		set_config "_processor_opt" "zen3"
	elif [ $vendor_id = "GenuineIntel" ]; then
		set_config "_processor_opt" "native_intel"
	elif [ $vendor_id = "AuthenticAMD" ]; then
		set_config "_processor_opt" "native_amd"
	fi

	# If no NVIDIA GPU is present, disable NUMA
	if (! lspci | grep -q -i 'NVIDIA Corporation'); then
		set_config "_numadisable" "true"
	fi

	clear
	makepkg -si --noconfirm
	sudo rm -r /tmp/*
}

# Check for an internet connection
if ! ping -c 1 google.com >/dev/null 2>&1; then
  echo "An internet connection is required to run this script."
  exit 1
fi

yay -S modprobed-db curl gawk --needed --noconfirm 

# If the modprobed database file doesn't exist, create it
if [ ! -f "$db_file" ]; then
	modprobed-db
fi

# Store currently loaded modules in the database
modprobed-db storesilent

# Add additional modules
cat $HOME/.config/modprobed_add.db >> $HOME/.config/modprobed.db

# Sort the list and remove duplicates in the database
sort -u $db_file -o $db_file
clear

# If the linux-tkg folder doesn't exist, clone it
if [ ! -d "$kernel_folder" ] || [ ! -d "$kernel_folder/.git" ]; then
	rm -rf "$kernel_folder"
	git clone https://github.com/Frogging-Family/linux-tkg $kernel_folder
fi

install_latest_kernel

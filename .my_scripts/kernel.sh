#!/bin/bash

db_file=~/.config/modprobed.db
kernel_folder=~/.my_scripts/linux-tkg
config=$kernel_folder/customization.cfg

# Define a list of extra modules to add to the kernel
modules=(
	ext4
	fat
	vfat
	loop
	isofs
	cifs
	efivarfs
	joydev
	ntfs
	ntfs3
	usb_storage
	usbhid
	xhci_pci
	xpad
)

install_latest_kernel(){
	cd $kernel_folder
	git pull --force

	# Modify package name to 'linux-tkg'
	sed -i 's/_custom_pkgbase=""/_custom_pkgbase="linux-tkg"/' $config

    # Set CPU scheduler to 'eevdf'
	sed -i 's/_cpusched=""/_cpusched="eevdf"/' $config

	# Enable compiler optimizations (-O3)
	sed -i 's/_compileroptlevel="1"/_compileroptlevel="2"/' $config 

	# Enable modprobeddb
	sed -i 's/_modprobeddb="false"/_modprobeddb="true"/' $config 

	# Tickless idle
	sed -i 's/_tickless=""/_tickless="2"/' $config 

	# Set timer frequency to 1000
	sed -i 's/_timer_freq=""/_timer_freq="1000"/' $config 

	# Disable ftrace
	sed -i 's/_ftracedisable="false"/_ftracedisable="true"/' $config 

	# Disable debugging
	sed -i 's/_debugdisable="false"/_debugdisable="true"/' $config 

	# Enable ACS override
	sed -i 's/_acs_override=""/_acs_override="true"/' $config

	# Enable Android modules for Waydroid
	sed -i 's/_waydroid=""/_waydroid="true"/' $config 

	# Disable menuconfig
	sed -i 's/_menunconfig=""/_menunconfig="0"/' $config 

	# Enable full LTO and use the LLVM compiler
	sed -i 's/_lto_mode=""/_lto_mode="full"/' $config 
	sed -i 's/_compiler=""/_compiler="llvm"/' $config

	# Compile for the native CPU architecture
	if grep -q "vendor_id\s*:\s*GenuineIntel" /proc/cpuinfo; then
	  sed -i 's/_processor_opt=""/_processor_opt="native_intel"/' $config
	elif grep -q "vendor_id\s*:\s*AuthenticAMD" /proc/cpuinfo; then
	  sed -i 's/_processor_opt=""/_processor_opt="native_amd"/' $config
	fi

	# If no NVIDIA GPU is present, disable NUMA
	if (! lspci | grep -q -i 'NVIDIA Corporation'); then
	  sed -i 's/_numadisable="false"/_numadisable="true"/' $config
	fi

	makepkg -si --noconfirm
	sudo sed -i "s/default.*/default tkg.conf/" /boot/loader/loader.conf
	exit 0
}

# If the modprobed database file doesn't exist, create it
if [ ! -f "$db_file" ]; then
	yay -S modprobe-db --needed --noconfirm 

	modprobed-db
fi

# Store currently loaded modules in the database
modprobed-db storesilent

# Add extra modules defined in the modules list to the database
for module in "${modules[@]}"; do
	echo "$module" >> "$db_file"
done

# Sort the list and remove duplicates in the database
sort -u $db_file
clear

# If the linux-tkg folder doesn't exist, clone it and install the latest kernel
if [ ! -d "$kernel_folder" ]; then
	git clone --depth 1 https://github.com/Frogging-Family/linux-tkg $kernel_folder
	install_latest_kernel
else 
	cd $kernel_folder

	current_commit=$(git rev-parse HEAD)
	latest_commit=$(git rev-parse origin/master) 

	if [ "$current_commit" != "$latest_commit" ]; then
		install_latest_kernel
	else
		echo "Already on latest kernel"
	fi
fi

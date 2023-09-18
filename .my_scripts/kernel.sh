#!/bin/bash

db_file=~/.config/modprobed.db
kernel_folder=~/.my_scripts/linux-tkg
config=$kernel_folder/customization.cfg

# Build directly from ram (Faster)
total_free_mem_bytes=$(free -b | awk '/^Mem/ { mem = $4 } /^Swap/ { swap = $4 } END { print mem + swap }')
min_required_mem_bytes=$((24 * 1024 * 1024 * 1024)) # 24GB

## Check if there is enough free memory
if ((total_free_mem_bytes >= min_required_mem_bytes)); then
    export BUILDDIR=/tmp/makepkg
fi

# If no db file, create a new db
if [ ! -f "$db_file" ]; then
	yay -S modprobe-db --needed --noconfirm 

	# Define the list of extra modules to add
	modules=(
	    ext4
	    fat
	    vfat
	    loop
	    isofs
	    cifs
	    efivarfs
	    joydev
	    usb_storage
	    usbhid
	    xhci_pci
	    xpad
	)

	# Create new DB
	modprobed-db

	# Add extra modules defined in modules list
	for module in "${modules[@]}"; do
		echo "$module" >> "$db_file"
	done

	# Sort list and remove duplicates
	sort -u $db_file
fi

# Store loaded modules
modprobed-db storesilent
clear

# Get latest kernel
if [ ! -d "$kernel_folder" ]; then
	git clone --depth 1 https://github.com/Frogging-Family/linux-tkg $kernel_folder
fi

# Go to kernel folder directory
cd $kernel_folder

current_commit=$(git rev-parse HEAD)
latest_commit=$(git rev-parse origin/master) 

if [ "$current_commit" != "$latest_commit" ]; then
	git pull --force

	# Change pkgname to linux-tkg
	sed -i 's/_custom_pkgbase=""/_custom_pkgbase="linux-tkg"/' $config

	# Change CPU scheduler to eevdf
	sed -i 's/_cpusched=""/_cpusched="eevdf"/' $config

	# Compiler optimizations (-O3)
	sed -i 's/_compileroptlevel="1"/_compileroptlevel="2"/' $config 

	# Enable modprobeddb
	sed -i 's/_modprobeddb="false"/_modprobeddb="true"/' $config 

	# Tickless idle
	sed -i 's/_tickless=""/_tickless="2"/' $config 

	# Timer freq
	sed -i 's/_timer_freq=""/_timer_freq="1000"/' $config 

	# Disable ftrace
	sed -i 's/_ftracedisable="false"/_ftracedisable="true"/' $config 

	# Disable debugging
	sed -i 's/_debugdisable="false"/_debugdisable="true"/' $config 

	 # Enable acs override
	sed -i 's/_acs_override=""/_acs_override="true"/' $config

	# Enable android modules for Waydroid
	sed -i 's/_waydroid=""/_waydroid="true"/' $config 

	# Disable menu config
	sed -i 's/_menunconfig=""/_menunconfig="0"/' $config 

	# Enable full LTO
	sed -i 's/_lto_mode=""/_lto_mode="full"/' $config 
	sed -i 's/_compiler=""/_compiler="llvm"/' $config

	# Compile for native CPU
	if grep -q "vendor_id\s*:\s*GenuineIntel" /proc/cpuinfo; then
	  sed -i 's/_processor_opt=""/_processor_opt="native_intel"/' $config
	elif grep -q "vendor_id\s*:\s*AuthenticAMD" /proc/cpuinfo; then
	  sed -i 's/_processor_opt=""/_processor_opt="native_amd"/' $config
	fi

	# If no NVIDIA GPU disable numa
	if (! lspci | grep -q -i 'NVIDIA Corporation'); then
	  sed -i 's/_numadisable="false"/_numadisable="true"/' $config
	fi

	makepkg -si --noconfirm
	sudo sed -i "s/default.*/default tkg.conf/" /boot/loader/loader.conf
else
	echo "Already on latest kernel"
fi

#!/bin/bash

db_file=~/.config/modprobed.db
kernel_folder=~/.my_scripts/linux-tkg
config=$kernel_folder/customization.cfg

# modprobeddb may already detect and load many of these modules automatically,
# but to ensure their inclusion in the database,
# i've created a list of additional kernel modules to add to the database.

modules=(
    ahci           # Advanced Host Controller Interface (SATA)
    btrfs          # B-tree File System
    btusb          # Bluetooth USB driver
    cifs           # Common Internet File System (SMB)
    ds4drv         # Sony DualShock 4 controller driver
    efivarfs       # EFI variables filesystem
    ext4           # Extended File System 4
    fat            # File Allocation Table filesystem
    hci_uart       # Bluetooth HCI UART driver
    hid-generic    # Generic HID (Human Interface Device) driver
    isofs          # ISO 9660 filesystem (CD/DVD)
    joydev         # Joystick device driver
    loop           # Loopback block device support
    md             # Multiple Device (MD) RAID support
    ntfs           # NTFS filesystem
    ntfs3          # NTFS-3G filesystem (NTFS read/write support)
    nvme           # NVMe (Non-Volatile Memory Express) driver
    raid           # RAID (Redundant Array of Independent Disks) support
    snd_usb_audio  # USB audio driver
    usb_storage    # USB storage driver
    usbcore        # USB core driver
    usbhid         # USB HID (Human Interface Device) driver
    tap            # TUN/TAP virtual network device (Layer 2)
    tun            # TUN/TAP virtual network device
    wireguard      # WireGuard VPN module
    vfat           # Virtual File Allocation Table filesystem
    vaapi          # Video Acceleration API
    xhci_pci       # xHCI PCI host controller driver (USB 3.0/3.1)
    xpad           # Xbox gamepad driver
)

ctrl_c() {
  exit 0
}

trap ctrl_c INT

install_latest_kernel(){
	cd $kernel_folder
	git pull --force

	# Modify package name to 'linux-tkg'
	sed -i 's/_custom_pkgbase=""/_custom_pkgbase="linux-tkg"/' $config

    # Set CPU scheduler to 'cacule'
	sed -i 's/_cpusched=""/_cpusched="cfs"/' $config

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

	clear
	echo "Current kernel version: $(echo "$(uname -r)" | cut -d- -f1)"
	echo -e "You can abort with Ctrl+C if you're on the same version \n"
	makepkg -si --noconfirm
	sudo sed -i "s/default.*/default tkg.conf/" /boot/loader/loader.conf
	exit 0
}

# If the modprobed database file doesn't exist, create it
if [ ! -f "$db_file" ]; then
	yay -S modprobed-db --needed --noconfirm 

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

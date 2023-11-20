#!/bin/bash

db_file=~/.config/modprobed.db
kernel_folder=~/.cache/linux-tkg
config_file=$kernel_folder/customization.cfg

# modprobeddb may already detect and load many of these modules automatically,
# but to ensure their inclusion in the database,
# i've created a list of additional kernel modules to add to the database.

modules_to_add=(
    ahci           # Advanced Host Controller Interface (SATA)
    btrfs          # B-tree File System
    btusb          # Bluetooth USB driver
    cifs           # Common Internet File System (SMB)
    ds4drv         # Sony DualShock 4 controller driver
    efivarfs       # EFI variables filesystem
    exfat		   # exFAT filesystem support
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
	git restore .
	git pull --force

	# Modify package name to 'linux-tkg'
	sed -i 's/_custom_pkgbase=""/_custom_pkgbase="linux-tkg"/' $config_file

    # Set CPU scheduler to 'eevdf'
	sed -i 's/_cpusched=""/_cpusched="eevdf"/' $config_file

	# Reduce overhead by lowering max cpu cores to current processor cores (Requires recompile on new CPU)
	sed -i 's/_NR_CPUS_value=""/_NR_CPUS_value="$(nproc)"/' $config_file
	
	# Enable compiler optimizations (-O3)
	sed -i 's/_compileroptlevel="1"/_compileroptlevel="2"/' $config_file 

	# Enable modprobeddb
	sed -i 's/_modprobeddb="false"/_modprobeddb="true"/' $config_file 

	# Tickless idle
	sed -i 's/_tickless=""/_tickless="2"/' $config_file 

	# Set timer frequency to 1000
	sed -i 's/_timer_freq=""/_timer_freq="1000"/' $config_file 

	# Disable ftrace
	sed -i 's/_ftracedisable="false"/_ftracedisable="true"/' $config_file 

	# Disable debugging
	sed -i 's/_debugdisable="false"/_debugdisable="true"/' $config_file 

	# Enable ACS override
	sed -i 's/_acs_override=""/_acs_override="true"/' $config_file

	# Enable Android modules for Waydroid
	sed -i 's/_waydroid=""/_waydroid="true"/' $config_file 

	# Disable menuconfig
	sed -i 's/_menunconfig=""/_menunconfig="0"/' $config_file 

	# Enable full LTO and use the LLVM compiler
	sed -i 's/_lto_mode=""/_lto_mode="full"/' $config_file 
	sed -i 's/_compiler=""/_compiler="llvm"/' $config_file

	# Compile for the native CPU architecture
	if grep -q "vendor_id\s*:\s*GenuineIntel" /proc/cpuinfo; then
	  sed -i 's/_processor_opt=""/_processor_opt="native_intel"/' $config_file
	elif grep -q "vendor_id\s*:\s*AuthenticAMD" /proc/cpuinfo; then
	  sed -i 's/_processor_opt=""/_processor_opt="native_amd"/' $config_file
	fi

	# If no NVIDIA GPU is present, disable NUMA
	if (! lspci | grep -q -i 'NVIDIA Corporation'); then
	  sed -i 's/_numadisable="false"/_numadisable="true"/' $config_file
	fi

	clear
	echo "Current kernel version: $(echo "$(uname -r)" | cut -d- -f1)"
	echo -e "You can abort with Ctrl+C if you're on the same version \n"
	makepkg -si --noconfirm
	sudo sed -i "s/default.*/default tkg.conf/" /boot/loader/loader.conf
	exit 0
}

yay -S modprobed-db --needed --noconfirm 

# If the modprobed database file doesn't exist, create it
if [ ! -f "$db_file" ]; then
	modprobed-db
fi

# Store currently loaded modules in the database
modprobed-db storesilent

# Add extra modules defined in the modules list to the database
for module in "${modules_to_add[@]}"; do
	echo "$module" >> "$db_file"
done

# Sort the list and remove duplicates in the database
sort -u $db_file -o $db_file
clear

# If the linux-tkg folder doesn't exist, clone it
if [ ! -d "$kernel_folder" ]; then
	git clone --depth 1 https://github.com/Frogging-Family/linux-tkg $kernel_folder
fi

install_latest_kernel

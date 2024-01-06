#!/bin/bash

db_file=~/.config/modprobed.db
kernel_folder=~/.cache/linux-tkg
config_file=$kernel_folder/customization.cfg
stable_kernel=$(curl -s https://www.kernel.org/finger_banner | grep -oP -m1 '\K\d+\.\d+\.\d+')

# modprobeddb may already detect and load many of these modules automatically,
# but to ensure their inclusion in the database,
# i've created a list of additional kernel modules to add to the database.

modules_to_add=(
    ahci           # Advanced Host Controller Interface (SATA)
    btrfs          # B-tree File System
    btusb          # Bluetooth USB driver
    conntrack      # Connection tracking for packet filtering and NAT
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

set_config(){
    sed "/$1=/ s/.*/$1=\"$2\"/" -i $config_file
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

	# Disable misc additions
	set_config "_misc_adds" "false"

	# Disable menuconfig
	set_config "_menunconfig" "0"

	# Enable full LTO and use the LLVM compiler
	set_config "_lto_mode" "full"
	set_config "_compiler" "llvm"

	# Force the use of the LLVM Integrated Assembler
	set_config "_llvm_ias" "1"

	# Compile for the native CPU architecture
	if grep -q "vendor_id\s*:\s*GenuineIntel" /proc/cpuinfo; then
		set_config "_processor_opt" "native_intel"
	elif grep -q "vendor_id\s*:\s*AuthenticAMD" /proc/cpuinfo; then
		set_config "_processor_opt" "native_amd"
	fi

	# If no NVIDIA GPU is present, disable NUMA
	if (! lspci | grep -q -i 'NVIDIA Corporation'); then
		set_config "_numadisable" "true"
	fi

	clear
	makepkg -si --noconfirm
	sudo sed -i "s/default.*/default tkg.conf/" /boot/loader/loader.conf
	exit 0
}

yay -S modprobed-db curl --needed --noconfirm 

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

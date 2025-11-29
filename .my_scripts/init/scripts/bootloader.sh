#!/bin/bash

tmp_entries_dir="$(mktemp -d)"

kernel_params=(
	# Reduce the attack surface of the system by reducing the amount of potentially sensitive information that is logged
	"loglevel=3"

	# Disables the debugfs file system, which can be a potential attack vector for exploits
	"debugfs=off"

	# Disables the vDSO which can be a potential attack vector for exploits
	"vsyscall=none"

	# Increase CPU performance, but might decrease battery life
	"processor.ignore_ppc=1"

	# Reduces overhead by disabling split-lock detection
	"split_lock_detect=off"

	# Improves boot times on harddrives
	"libahci.ignore_sss=1"

	# Reduce writes to SSD 
	"rootflags=noatime"

	# Disable USB power management
	"usbcore.autosuspend=-1"

	# Stop rfkill from soft-blocking
	"rfkill.default_state=1"
	"rfkill.master_switch_mode=2"

	# Enable MSI to reduce latency
	"amdgpu.msi=1"
	"nvidia.NVreg_EnableMSI=1"

	# Disable watchdog to reduce overhead
	"nowatchdog"
	"nmi_watchdog=0"
	"module_blacklist=iTCO_wdt"

	# Disable amdgpu audio 
	"amdgpu.audio=0"

	# Enable AMD GPU overclocking
	"amdgpu.ppfeaturemask=0xffffffff"
)

kernel_params_str=$(printf "%s " "${kernel_params[@]}")

microcode () {
	if [ -n "$(cat /proc/cpuinfo | grep 'AuthenticAMD')" ]; then
		sudo pacman -S amd-ucode --needed --ask 4
		sed -i '3 i initrd /amd-ucode.img' $tmp_entries_dir/*.conf
	elif [ -n "$(cat /proc/cpuinfo | grep 'GenuineIntel')" ]; then
		sudo pacman -S intel-ucode --needed --ask 4
		sed -i '3 i initrd /intel-ucode.img' $tmp_entries_dir/*.conf
	fi
}

enable_hibernation () {
	sudo sed -i 's/^[ \t]*HOOKS=(base udev autodetect/HOOKS=(base udev resume autodetect/' /etc/mkinitcpio.conf
}

add_options () {
	get_root_uuid (){
		ROOT_DRIVE=$(df -hT / | awk 'NR==2 {print $1}')
		ROOT_UUID=$(sudo blkid -o value -s UUID $ROOT_DRIVE)
		sudo tune2fs -O fast_commit $ROOT_DRIVE
	}
	
	get_swap_uuid () {
		SWAP_DRIVE=$(swapon --show=NAME --noheadings --raw | awk '{print $1}')
		SWAP_UUID=$(sudo blkid -o value -s UUID $SWAP_DRIVE)
	}

	get_root_uuid
	if [ -n "$(lsblk | grep SWAP)" ]; then get_swap_uuid; fi

	if [[ -n $SWAP_UUID && -n $ROOT_UUID ]]; then
		echo "options root=UUID=$ROOT_UUID resume=UUID=$SWAP_UUID rw $kernel_params_str" | tee -a $tmp_entries_dir/*.conf
		enable_hibernation
	elif [[ -z $SWAP_UUID && -n $ROOT_UUID ]]; then
		echo "options root=UUID=$ROOT_UUID rw $kernel_params_str" | tee -a $tmp_entries_dir/*.conf
	fi
}

# Install systemd-boot
if [ ! -d "/boot/loader" ]; then
    sudo bootctl install
fi

# Loader config
echo "timeout 0" | sudo tee "/boot/loader/loader.conf" > /dev/null


# Check if the cachyos repo is enabled
if grep -q "\[cachyos\]" /etc/pacman.conf; then
    # Install CachyOS kernels
    sudo pacman -S --noconfirm --needed linux-cachyos linux-cachyos-headers linux-lts linux-lts-headers

    # Set default boot entry
    echo "default cachyos.conf" | sudo tee -a /boot/loader/loader.conf > /dev/null
    sudo bootctl set-default cachyos.conf
else
    # Install Zen kernel if CachyOS repo is not present
    sudo pacman -S --noconfirm --needed linux-zen linux-zen-headers linux-lts linux-lts-headers

    # Set default boot entry
    echo "default linux-zen.conf" | sudo tee -a /boot/loader/loader.conf > /dev/null
    sudo bootctl set-default linux-zen.conf
fi

# Create temp kernel entries
cp ~/.my_scripts/init/system/boot/loader/templates/*.conf $tmp_entries_dir

# Add Intel or AMD microcode
microcode

# Add options to kernel configuration files with tweaks
add_options

# Copy to boot
sudo cp -r $tmp_entries_dir/. /boot/loader/entries

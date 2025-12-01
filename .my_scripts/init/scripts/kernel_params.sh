#!/bin/bash

kernel_params=(
	# Default parameters
	"rhgb"
	"quiet"

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


# 2️⃣ Join parameters into a single string
params_str="${kernel_params[*]}"
# Replace spaces with single space
params_str="${params_str// / }"

# 3️⃣ Update GRUB_CMDLINE_LINUX in /etc/default/grub
sudo sed -i -E "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${params_str}\"|" /etc/default/grub
echo "GRUB_CMDLINE_LINUX updated with your kernel parameters."
sudo  grub2-mkconfig -o /boot/grub2/grub.cfg
echo "GRUB configuration rebuilt."

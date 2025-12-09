#!/bin/bash

get_primary_gpu() {
    ###############################
    # Method 1: DRM vendor detection
    ###############################
    local gpu vendor

    gpu=$(ls -1 /sys/class/drm/ | grep "^card[0-9]$" | head -n 1 2>/dev/null)

    if [[ -n "$gpu" ]]; then
        vendor=$(cat "/sys/class/drm/$gpu/device/vendor" 2>/dev/null)

        case "$vendor" in
            0x10de) echo "nvidia"; return ;;
            0x1002) echo "amd";    return ;;
            0x8086) echo "intel";  return ;;
        esac
    fi

    ###############################
    # Method 2: Kernel modules
    ###############################
    if lsmod | grep -q "^nvidia"; then
        echo "nvidia"; return
    elif lsmod | grep -q "^amdgpu"; then
        echo "amd"; return
    elif lsmod | grep -q "^i915"; then
        echo "intel"; return
    fi

    ###############################
    # Method 3: /dev/dri symlink
    ###############################
    local dri
    dri=$(readlink -f /dev/dri/card0 2>/dev/null)

    if [[ "$dri" == *"nvidia"* ]]; then
        echo "nvidia"; return
    elif [[ "$dri" == *"amdgpu"* ]]; then
        echo "amd"; return
    elif [[ "$dri" == *"i915"* || "$dri" == *"intel"* ]]; then
        echo "intel"; return
    fi

    ###############################
    # Nothing matched
    ###############################
    echo "unknown"
}

nvidia_drivers () {
	echo "Nvidia GPU drivers not yet implemented..."
    read -p "Press enter to continue"	
}

amd_drivers () {
    gpu_packages=("mesa" "lib32-mesa" "vulkan-radeon" "lib32-vulkan-radeon" "vulkan-icd-loader" "lib32-vulkan-icd-loader" "libva-utils")
    sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf

    ##############################
	# Enables overclocking below
	##############################
	original_conf_file="$SCRIPT_DIR/system/etc/amd-overclock.original"
	conf_file="/etc/amd-overclock.conf"

	if [ ! -f "$conf_file" ]; then
		cp -f $original_conf_file $conf_file
		
		# Comment out each variable in the config file
		sed -i 's/^\(VOLTAGE_OFFSET=.*\)/#\1/' "$conf_file"
		sed -i 's/^\(CORE_CLOCK=.*\)/#\1/' "$conf_file"
		sed -i 's/^\(MEMORY_CLOCK=.*\)/#\1/' "$conf_file"
		sed -i 's/^\(MAX_WATTS_POWERLIMIT=.*\)/#\1/' "$conf_file"

		clear_screen
		printf "Overclock values will be commented out by default.\n\n"
		printf "You will need to modify ${YELLOW}$conf_file${RESET}"

		printf "\n\n"
		read -p "Press enter to continue"

		# Edit config file 
	    pacman -Syu micro --ask 4 --needed
		micro $conf_file

		# Enable service
		systemctl enable amd-overclock.service
	fi
}

intel_drivers () {
    gpu_packages=("mesa" "lib32-mesa" "vulkan-intel" "lib32-vulkan-intel" "intel-media-driver")
}

while true; do
    gpu="$(get_primary_gpu)"

    if [[ "$gpu" == "nvidia" ]]; then
        nvidia_drivers
        break
    elif [[ "$gpu" == "amd" ]]; then
        amd_drivers
        break
    elif [[ "$gpu" == "intel" ]]; then
        intel_drivers
        break
    else
        echo "An ERROR occurred at GPU drivers section: GPU='$gpu'"
        break
    fi
done

pacman -Syu ${gpu_packages[@]} --ask 4 --needed

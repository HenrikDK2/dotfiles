#!/bin/bash

function confirm() {
    while true; do
        read -p " [y/n] " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) printf "\nPlease answer YES or NO";;
        esac
    done
}

function get_stable_kernel(){
	local stable_kernel=$(pacman -Si linux | grep Version | awk '{print $3}' | sed 's/^\([0-9]\+\(\.[0-9]\+\)*\).*/\1/')

	if [[ $stable_kernel == *.* && $stable_kernel != *.*.* ]]; then
	    stable_kernel="${stable_kernel}.0"
	fi

	 echo "$stable_kernel"
}

function get_primary_gpu() {
	local amd=$(lspci -vnn | grep VGA -A 12 | grep -i amdgpu)
	local intel=$(lspci -vnn | grep VGA -A 12 | grep -i Intel)
	local nvidia=$(lspci -vnn | grep VGA -A 12 | grep -i NVIDIA)

	if [ ! -z "$nvidia" ]; then
		echo "nvidia"
	elif [ ! -z "$amd" ]; then
		echo "amd"
	elif [ ! -z "$intel" ]; then
		echo "intel"
	fi

	exit 0
}

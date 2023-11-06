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

function filter_fastest_mirrors () {
	if [ ! -f "$1" ]; then
		exit 1
	fi
	
	local MIRROR_TMP="$HOME/.cache/mirror.tmp"
	local mirror_speeds=()
	
	echo -e "\n-----------------------------------------------------------------"
	echo -e "Finding fastest mirrors in $1"
	echo -e "-----------------------------------------------------------------\n"
	
	cat "$1" > $MIRROR_TMP
	sed -i '/^#/d' $MIRROR_TMP
	sed -i 's/Server = //' $MIRROR_TMP

	while IFS= read -r mirror; do
	    mirror_speed=$(curl -s -o /dev/null -w '%{speed_download}\n' "$mirror")
        mirror_speeds+=("$mirror_speed $mirror")
	done < "$MIRROR_TMP"

	# Sort the mirror_speeds array by speed in descending order
    IFS=$'\n' mirror_speeds=($(sort -r -n <<<"${mirror_speeds[*]}"))

	# Reset mirror.tmp
	rm $MIRROR_TMP
	
    # Output the sorted mirrors to the specified file
    for item in "${mirror_speeds[@]}"; do
        mirror_url=${item#* }
        echo "Server = $mirror_url" >> "$MIRROR_TMP"
    done

    cat $MIRROR_TMP | sudo tee $1
}

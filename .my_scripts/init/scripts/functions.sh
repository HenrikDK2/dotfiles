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

# $1 - Mirrorlist file path
# $2 - File to download minus url path to mirror
function sort_fastest_mirrors() {
    if [ ! -f "$1" ]; then
        exit 1
    fi

    local mirror_tmp="$HOME/.cache/mirror.tmp"
    local mirror_speeds=()

    echo -e "\n-----------------------------------------------------------------"
    echo -e "Finding fastest mirrors in $1"
    echo -e "-----------------------------------------------------------------\n"

    cat "$1" >$mirror_tmp
    sed -i '/^#/d' $mirror_tmp
    sed -i 's/Server = //' $mirror_tmp

    # Loop through each mirror in the mirrorlist
    while IFS= read -r mirror; do
        local mirror_url=$(echo "$mirror" | sed 's|/\$.*$|/|')
        local mirror_speed=$(curl -s -o /dev/null -w '%{speed_download}\n' "$mirror_url/$2")

        if [ "$(bc <<<"$mirror_speed > 0")" -eq 1 ]; then
            mirror_speeds+=("$mirror_speed $mirror")
        fi
    done <"$mirror_tmp"

    # Sort the mirror_speeds array by speed in descending order
    IFS=$'\n' mirror_speeds=($(sort -r -n <<<"${mirror_speeds[*]}"))

    # Reset mirror.tmp
    rm $mirror_tmp

    # Output the sorted mirrors to the specified file
    for item in "${mirror_speeds[@]}"; do
        mirror_url=${item#* }
        echo "Server = $mirror_url" >>"$mirror_tmp"
    done

    # Update the original mirrorlist file with the sorted mirrors
    cat $mirror_tmp | sudo tee $1
}

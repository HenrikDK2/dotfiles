#!/bin/bash

# $1 - offset from top (default: 0)
function clear_screen() {
    local lines=$(tput lines)
    local offset=${1:-0}
    local clear_lines=$((lines - offset))

    if (( clear_lines < 0 )); then
        clear_lines=0
    fi

    # Push old content off
    for ((i=0; i<clear_lines; i++)); do
        echo ""
    done

    # Move prompt up by printing blank lines after clearing
    tput cup "$offset" 0
}

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
}

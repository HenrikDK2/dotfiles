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

function auto_install() {
    # Exit if no arguments are passed
    if [ $# -eq 0 ]; then
        echo "Error: At least one package name is required"
        echo "Usage: auto_install <package1> [package2...]"
        return 1
    fi

	if command -v yay > /dev/null; then
	    yay -Syu "$@" --noconfirm \
	        --noredownload \
	        --needed \
	        --useask \
	        --ask 4 \
	        --cleanmenu=0 \
	        --diffmenu=0 \
	        --editmenu=0 \
	        --answerdiff None \
	        --answeredit None \
	        --answerclean All \
	        --answerupgrade All \
	        --overwrite="*" \
	else
	    sudo pacman -Syu "$@" --noconfirm \
	        --overwrite="*" \
	        $rebuild_flags
	fi
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

# Function to set Java version based on the number
function set_java_version() {
    if [ -z "$1" ]; then
        echo "Usage: set_java_version <java_version_number>"
        return 1
    fi
    
    # Construct the expected path based on the input version number
    JAVA_VERSION="java-$1-openjdk"
    JAVA_PATH="/usr/lib/jvm/$JAVA_VERSION"

	# If java version is not found, then install
	if [ ! -d "$JAVA_PATH" ]; then
    	yay -S "jre$1-openjdk" --needed --ask 4
    fi
    
    # Check if the specified Java path exists
    if [ -d "$JAVA_PATH" ]; then
        sudo archlinux-java set $JAVA_VERSION
        export JAVA_HOME="$JAVA_PATH"
        export PATH="$JAVA_HOME/bin:$PATH"
        
        # Confirm the Java version
        java -version
        archlinux-java status
    else
        echo "Error: Java version $1 not found at $JAVA_PATH"
        return 1
    fi
}

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
		clear
        java -version
        archlinux-java status
    else
        echo "Error: Java version $1 not found at $JAVA_PATH"
        return 1
    fi
}

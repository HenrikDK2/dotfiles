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
	local stable_kernel=$(curl -s https://www.kernel.org/finger_banner | grep -oP 'The latest stable version of the Linux kernel is:\s+\K[\d.]+')

	# If kernel is on new minor version, and linux-tkg is installed, then skip minor version until first patch
	if [[ $stable_kernel == *.* && $stable_kernel != *.*.* ]]; then
		if pacman -Qi linux-tkg &> /dev/null; then 
	    	stable_kernel=$(pacman -Qi linux-tkg | awk '/^Version/ {print $3}' | cut -d'-' -f1)
		fi
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
}

# Function to set Java version based on the number
function set-java() {
    if [ -z "$1" ]; then
        echo "Usage: set-java <java_version_number>"
        return 1
    fi
    
    # Construct the expected path based on the input version number
    JAVA_PATH="/usr/lib/jvm/java-$1-openjdk"

	# If java version is not found, then install
	if [ ! -d "$JAVA_PATH" ]; then
    	sudo pacman -S "jdk$1-openjdk" --needed
    fi
    
    # Check if the specified Java path exists
    if [ -d "$JAVA_PATH" ]; then
        export JAVA_HOME="$JAVA_PATH"
        export PATH="$JAVA_HOME/bin:$PATH"
        
        # Confirm the Java version
        java -version
        echo "JAVA_HOME set to $JAVA_HOME"
    else
        echo "Error: Java version $1 not found at $JAVA_PATH"
        return 1
    fi
}

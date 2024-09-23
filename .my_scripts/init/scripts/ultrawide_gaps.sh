#!/bin/bash

# Read the virtual size from the file
virtual_size=$(cat /sys/class/graphics/fb0/virtual_size)

# Extract width and height
width=$(echo "$virtual_size" | cut -d',' -f1)
height=$(echo "$virtual_size" | cut -d',' -f2)

# Calculate the aspect ratio
gcd() {
    local a=$1
    local b=$2
    while [ "$b" -ne 0 ]; do
        local temp=$b
        b=$((a % b))
        a=$temp
    done
    echo "$a"
}

gcd_value=$(gcd "$width" "$height")
aspect_width=$(( width / gcd_value ))
aspect_height=$(( height / gcd_value ))
aspect_ratio="$aspect_width:$aspect_height"

if [ "$aspect_ratio" = "32:9" ]; then
    mkdir -p ~/.config/sway/config.d
    cp ~/.my_scripts/init/config.d/workspace-gaps ~/.config/sway/config.d/workspace-gaps
fi

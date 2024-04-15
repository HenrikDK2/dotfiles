#!/bin/bash

# Directory containing the images
directory="$HOME/Wallpapers/"
bg_conf="$HOME/.config/sway/config.d/bg.conf"

# Function to get the last file used in bg.conf
get_last_bg() {
    awk '/bg/ {print $2}' $bg_conf | tail -n 1
}

# Get the last background file
last_bg=$(get_last_bg)

# Get a random image file
file=$(find "$directory" -type f \( -name "*.png" -o -name "*.jpg" \) | shuf -n 1)

# Check if the new file is the same as the last one
while [[ "$file" == "$last_bg" ]]; do
    file=$(find "$directory" -type f \( -name "*.png" -o -name "*.jpg" \) | shuf -n 1)
done

# Write the configuration to file
echo "output * {
    bg $file center
}" > $bg_conf


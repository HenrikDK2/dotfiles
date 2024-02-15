#!/bin/bash

download_dir="$HOME/.cache/wine-ge-latest"
wine_dir="/home/henrik/.config/heroic/tools/wine/Wine-GE-Latest"
current_filename=$(cat "$wine_dir/.filename")

json_data=$(curl -s "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases/latest")
url=$(echo "$json_data" | jq -r '.assets[1].browser_download_url')

filename=$(basename "$url")
file="$download_dir/$filename"

# Check if current installed version had the same filename
if [ "$current_filename" = "$filename" ]; then
	exit 0
fi

# Download latest wine-ge-custom release
curl -LO --create-dirs --output-dir "$download_dir" "$url"

if [ -f "$file" ]; then
	rm -rf "$wine_dir"
	mkdir "$wine_dir"
	tar -xvf "$file" -C "$wine_dir" --strip-components=1
	echo "$filename" > "$wine_dir/.filename"
	rm -rf $download_dir
fi

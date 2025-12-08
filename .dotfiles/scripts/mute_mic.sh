#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sound_dir="$script_dir/sounds"
source_name=$(pactl get-default-source)

# Get the mute status of the specified source
mute_status=$(pactl get-source-mute "$source_name" | awk '{print $2}')

# Toggle mute
if [ "$mute_status" == "yes" ]; then
    pactl set-source-mute "$source_name" 0
    mpv --no-terminal $sound_dir/unmute.mp3
elif [ "$mute_status" == "no" ]; then
    pactl set-source-mute "$source_name" 1
    mpv --no-terminal $sound_dir/mute.mp3
fi

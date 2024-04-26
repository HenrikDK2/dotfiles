#!/bin/bash

source_name=$(pactl get-default-source)

# Get the mute status of the specified source
mute_status=$(pactl get-source-mute "$source_name" | awk '{print $2}')

# Toggle mute
if [ "$mute_status" == "yes" ]; then
    pactl set-source-mute "$source_name" 0
    notify-send --urgency=low "Microphone is unmuted"
elif [ "$mute_status" == "no" ]; then
    pactl set-source-mute "$source_name" 1
    notify-send --urgency=low "Microphone is muted"
fi

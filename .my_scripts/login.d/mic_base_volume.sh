#!/bin/bash

## Volume above base volume gets distorted on microphones

# Get the default source (microphone) name
DEFAULT_MIC=$(pactl info | grep "Default Source" | awk '{print $3}')

# Retrieve the Base Volume percentage of the default microphone
BASE_VOLUME=$(pactl list sources | grep -A 20 "Name: $DEFAULT_MIC" | grep 'Base Volume:' | awk '{print $5}')

# Set volume to base of microphone
pactl set-source-volume "$DEFAULT_MIC" "$BASE_VOLUME"

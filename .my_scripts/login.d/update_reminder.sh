#!/bin/bash

log_file="/var/log/pacman.log"
last_modified=$(stat -c %Y "$log_file")
current_time=$(date +%s)
week_in_seconds=$(( 7 * 24 * 60 * 60 ))
time_diff=$(( current_time - last_modified ))
updates_available=$(pacman -Qu --check)

if [[ -n $updates_available && $time_diff -lt $week_in_seconds ]]; then
	kitty sh -c 'echo -e "\033[1;33mYou have not updated in over a week!\033[0m\n"; ~/.my_scripts/update.sh;'
fi

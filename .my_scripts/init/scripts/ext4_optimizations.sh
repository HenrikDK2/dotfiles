#!/bin/bash

# Loop through the drives in /etc/fstab
while read -r line; do
  if [[ "$line" =~ ^UUID= ]]; then
    drive_info=($line)
    uuid="${drive_info[0]}"
    mount_point="${drive_info[1]}"
    format="${drive_info[2]}"
    options="${drive_info[3]}"
	pass="${drive_info[4]} ${drive_info[5]}"
	new_options="$options"

    if [[ $format == "ext4" ]]; then
	    if [[ "$options" != *noatime* ]]; then
	      new_options="${new_options},noatime"
	    fi

	    if [[ "$options" != *commit* ]]; then
	      new_options="${new_options},commit=60"
	    fi

    	sudo sed -i "s|$line|${uuid}\t\t${mount_point}\t\t${format}\t\t${new_options}\t\t${pass}|" /etc/fstab
    fi
  fi
done < /etc/fstab

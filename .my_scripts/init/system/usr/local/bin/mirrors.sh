#!/bin/bash

internet_loops=0

main () {
	if ! command -v rate-mirrors &> /dev/null; then
	    echo "Error: rate-mirrors command is not available." >&2
	    exit 1
	fi

	if ! command -v cachyos-rate-mirrors &> /dev/null; then
	    echo "Error: cachyos-rate-mirrors command is not available." >&2
	    exit 0
	fi

	# Check for an internet connection
	if ! ping -c 1 google.com >/dev/null 2>&1; then
	  if $internet_loops -lt 10; then
		sleep 10
		internet_loops=$((internet_loops + 1))
		main
	  else
	  	echo "An internet connection is required to run this script."
	  	exit 1
	  fi
	fi

	# Update arch mirrors
	rate-mirrors --disable-comments-in-file --allow-root --protocol=https arch | tee /etc/pacman.d/mirrorlist

	# Update cachyos mirrors
	cachyos-rate-mirrors
}

main

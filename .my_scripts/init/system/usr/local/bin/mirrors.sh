#!/bin/bash

if ! command -v rate-mirrors &> /dev/null; then
    echo "Error: rate-mirrors command is not available." >&2
    exit 1
fi

if ! command -v cachyos-rate-mirrors &> /dev/null; then
    echo "Error: cachyos-rate-mirrors command is not available." >&2
    exit 1
fi

main () {
	# Service should first start when network is online
	# But if for some reason connection isn't found it will continue to loop every minute
	if ! ping -c 1 google.com >/dev/null 2>&1; then
		sleep 1m
		main
	fi

	# Update arch mirrors
	rate-mirrors --disable-comments-in-file --allow-root --protocol=https arch | tee /etc/pacman.d/mirrorlist

	# Update cachyos mirrors
	cachyos-rate-mirrors
}

main

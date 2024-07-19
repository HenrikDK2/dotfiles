#!/bin/bash

if ! command -v rate-mirrors &> /dev/null; then
    echo "Error: rate-mirrors command is not available." >&2
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
    rate-mirrors --save=/tmp/mirrorlist.tmp --disable-comments-in-file --allow-root --protocol=https arch

    if [ $? -eq 0 ] && [ -s /tmp/mirrorlist.tmp ]; then
        mv /tmp/mirrorlist.tmp /etc/pacman.d/mirrorlist
        echo "Mirrorlist updated successfully."
    else
        echo "Error occurred while refreshing mirrors. Mirrorlist not updated."
        rm /tmp/mirrorlist.tmp
    fi
}

main

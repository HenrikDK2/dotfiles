#!/bin/bash

for drive in /mnt/*; do
    if [ -d "$drive" ]; then
        if mount | grep "on $drive " > /dev/null; then
            flatpak override --user --filesystem=$drive
        fi
    fi
done

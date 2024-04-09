#!/bin/bash

if ! command -v rate-mirrors &> /dev/null; then
    echo "Error: rate-mirrors command is not available." >&2
    exit 1
fi

if ! command -v cachyos-rate-mirrors &> /dev/null; then
    echo "Error: cachyos-rate-mirrors command is not available." >&2
    exit 1
fi

# Update arch mirrors
rate-mirrors --disable-comments-in-file --allow-root --protocol=https arch  | sudo tee /etc/pacman.d/mirrorlist

# Update cachyos mirrors
cachyos-rate-mirrors

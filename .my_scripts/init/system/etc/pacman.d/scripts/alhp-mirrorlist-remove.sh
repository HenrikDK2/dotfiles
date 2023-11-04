#!/bin/bash

sed -i '/^\[core-x86-64-v3\]/,/^Include = \/etc\/pacman.d\/alhp-mirrorlist$/d' /etc/pacman.conf
sed -i '/^\[extra-x86-64-v3\]/,/^Include = \/etc\/pacman.d\/alhp-mirrorlist$/d' /etc/pacman.conf
sed -i '/^\[multilib-x86-64-v3\]/,/^Include = \/etc\/pacman.d\/alhp-mirrorlist$/d' /etc/pacman.conf

# Remove multiple newlines
sed -i '/^$/N;/^\n$/D' /etc/pacman.conf

#!/bin/bash

sed -i '/^\[cachyos\]/,/^Include = \/etc\/pacman.d\/cachyos-mirrorlist$/d' /etc/pacman.conf
sed -i '/^\[cachyos-v3\]/,/^Include = \/etc\/pacman.d\/cachyos-v3-mirrorlist$/d' /etc/pacman.conf
sed -i '/^\[cachyos-core-v3\]/,/^Include = \/etc\/pacman.d\/cachyos-v3-mirrorlist$/d' /etc/pacman.conf
sed -i '/^\[cachyos-extra-v3\]/,/^Include = \/etc\/pacman.d\/cachyos-v3-mirrorlist$/d' /etc/pacman.conf
sed -i '/^\[cachyos-v4\]/,/^Include = \/etc\/pacman.d\/cachyos-v4-mirrorlist$/d' /etc/pacman.conf
sed -i '/^\[cachyos-core-v4\]/,/^Include = \/etc\/pacman.d\/cachyos-v4-mirrorlist$/d' /etc/pacman.conf
sed -i '/^\[cachyos-extra-v4\]/,/^Include = \/etc\/pacman.d\/cachyos-v4-mirrorlist$/d' /etc/pacman.conf

# Remove multiple newlines
sed -i '/^$/N;/^\n$/D' /etc/pacman.conf

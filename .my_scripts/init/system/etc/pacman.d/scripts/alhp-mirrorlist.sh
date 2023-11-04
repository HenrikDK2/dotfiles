#!/bin/bash

# Remove worldwide mirror
sudo sed -i '/https:\/\/alhp.krautflare.de\/$repo\/os\/$arch\//d' /etc/pacman.d/alhp-mirrorlist

# Resolve potential issues with signatures
rm -rf /etc/pacman.d/gnupg/
pacman-key --init
pacman-key --populate

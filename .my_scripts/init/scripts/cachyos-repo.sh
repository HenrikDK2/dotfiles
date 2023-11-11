#!/bin/bash

source $HOME/.my_scripts/init/scripts/functions.sh

# Install CachyOS
wget https://mirror.cachyos.org/cachyos-repo.tar.xz -P $HOME
tar xvf $HOME/cachyos-repo.tar.xz
cd $HOME/cachyos-repo
sudo ./cachyos-repo.sh
rm -rf $HOME/*cachyos-repo*

# Get the fastest CachyOS mirrors
sort_fastest_mirrors "/etc/pacman.d/cachyos-v3-mirrorlist" "x86_64_v3/cachyos-v3/cachyos-v3.files"
sort_fastest_mirrors "/etc/pacman.d/cachyos-v4-mirrorlist" "x86_64_v4/cachyos-v4/cachyos-v4.files"
sort_fastest_mirrors "/etc/pacman.d/cachyos-mirrorlist" "x86_64/cachyos/cachyos.files"

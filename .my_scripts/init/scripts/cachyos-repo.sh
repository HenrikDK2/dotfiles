#!/bin/bash

source $HOME/.my_scripts/init/scripts/functions.sh

wget https://mirror.cachyos.org/cachyos-repo.tar.xz -P $HOME
tar xvf $HOME/cachyos-repo.tar.xz
cd $HOME/cachyos-repo
sudo ./cachyos-repo.sh
rm -rf $HOME/*cachyos-repo*

find_fastest_mirrors "/etc/pacman.d/cachyos-mirrorlist"
find_fastest_mirrors "/etc/pacman.d/cachyos-v3-mirrorlist"
find_fastest_mirrors "/etc/pacman.d/cachyos-v4-mirrorlist"

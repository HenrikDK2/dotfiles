#!/bin/sh

# Reduce priority of this script
renice -n 20 $$
ionice -c idle -p $$
clear

yay -Syu --noconfirm

while ! [ "$(pacman -Qdtq)" = "" ]; do
	sudo pacman -Rn $(pacman -Qdtq) --noconfirm
done

sudo rm -rf /tmp/*
rm -rf ~/.local/share/Trash/*
sudo pacman -Sc --noconfirm
sudo yay -Sc --noconfirm
rm -rf ~/.cache/yay/*
clear

exec ~/.my-scripts/tkg.sh

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
rm -rf ~/.cache/*
rm -rf ~/.local/share/applications/
clear

exec ~/.my_scripts/tkg.sh

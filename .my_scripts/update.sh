#!/bin/sh

# Reduce priority of this script
renice -n 20 $$
ionice -c idle -p $$
clear

yay -Syu --noconfirm --needed

while ! [ "$(pacman -Qdtq)" = "" ]; do
	sudo pacman -Rn $(pacman -Qdtq) --noconfirm --needed
done

sudo rm -rf /tmp/*
rm -rf ~/.local/share/Trash/*
rm -rf ~/.local/share/applications/
sudo yay -Scc --noconfirm --needed
clear

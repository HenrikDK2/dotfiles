#!/bin/sh

# Reduce priority of this script
renice -n 20 $$
ionice -c idle -p $$
clear

yay -Syu --noconfirm --needed

while ! [ "$(pacman -Qdtq)" = "" ]; do
	sudo pacman -Rsunc $(pacman -Qdtq) --noconfirm
done

rm -rf ~/.local/share/Trash/*
rm -rf ~/.local/share/applications/
sudo yay -Scc --noconfirm --needed

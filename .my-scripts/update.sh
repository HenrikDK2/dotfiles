#!/bin/sh

yay -Syu --noconfirm
yay -Scc --noconfirm

while ! [ "$(pacman -Qdtq)" = "" ]; do
	sudo pacman -Rn $(pacman -Qdtq) --noconfirm
done

sudo rm -rf /tmp/*
rm -rf ~/.local/share/Trash/*
sudo pacman -Scc --noconfirm
sudo yay -Scc --noconfirm
clear

exec ~/.my-scripts/tkg.sh
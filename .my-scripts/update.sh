#!/bin/sh

yay -Syu --noconfirm

while ! [ "$(pacman -Qdtq)" = "" ]; do
	sudo pacman -Rn $(pacman -Qdtq) --noconfirm
done

sudo rm -rf /tmp/*
rm -rf ~/.local/share/Trash/*


exec ~/.my-scripts/tkg.sh
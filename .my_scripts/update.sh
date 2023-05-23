#!/bin/sh

yay -Syu --noconfirm --needed

while ! [ "$(pacman -Qdtq)" = "" ]; do
	sudo pacman -Rsunc $(pacman -Qdtq) --noconfirm
done

sudo yay -Scc --noconfirm --needed

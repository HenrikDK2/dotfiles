#!/bin/sh

yay -Syu --noconfirm --needed

while ! [ "$(pacman -Qdtq)" = "" ]; do
	sudo pacman -Rsunc $(pacman -Qdtq) --noconfirm
done

sudo yay -Scc --noconfirm --needed

clear
echo -e "\033[1mBeginning audit.\033[0m\n"
~/.my_scripts/audit.sh
read -p "Press enter to continue"

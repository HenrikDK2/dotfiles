#!/bin/bash

source $HOME/.my_scripts/init/scripts/functions.sh

clear
printf "Do you want to install the required tools for android development?"

if confirm; then
	yay -S watchman-bin python jdk-openjdk android-tools android-studio --needed --noconfirm
fi

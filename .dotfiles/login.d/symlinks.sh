#!/bin/bash

# Symlink steamapps to "$HOME/Games" folder
FLATPAK_STEAMAPPS="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps"
SYMLINK_STEAMAPPS="$HOME/Games/steamapps"

if [ ! -d $SYMLINK_STEAMAPPS ]; then
	mkdir -p $FLATPAK_STEAMAPPS
	ln -s $FLATPAK_STEAMAPPS $SYMLINK_STEAMAPPS
fi

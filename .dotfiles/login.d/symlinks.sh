#!/bin/bash

# Symlink steamapps to "$HOME/Games" folder
STEAMAPPS="$HOME/.local/share/Steam/steamapps"
SYMLINK_STEAMAPPS="$HOME/Games/steamapps"

if [ ! -d $SYMLINK_STEAMAPPS ]; then
	mkdir -p $STEAMAPPS
	ln -s $STEAMAPPS $SYMLINK_STEAMAPPS
fi

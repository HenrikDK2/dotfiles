#!/bin/bash

# The script will copy the config settings only if the Heroic folder is empty.

NATIVE_DIR="$HOME/.config/heroic"

if [ ! -d "$NATIVE_DIR" ]; then
	mkdir -p $NATIVE_DIR
	cp -r $DIR/user/heroic $NATIVE_DIR
	sed -i "s/Henrik/$USER/" $NATIVE_DIR/config.json
fi

FLATPAK_DIR="$HOME/.var/app/com.heroicgameslauncher.hgl/config/heroic"

if [ ! -d "$FLATPAK_DIR" ]; then
	mkdir -p $FLATPAK_DIR
	cp -r $DIR/user/heroic $FLATPAK_DIR
	sed -i "s/Henrik/$USER/" $FLATPAK_DIR/config.json
fi

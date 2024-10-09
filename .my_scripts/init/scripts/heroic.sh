#!/bin/bash

# Config settings for Heroic Games Launcher
if [ ! -d "$HOME/.config/heroic" ]; then
	cp -r $HOME/.my_scripts/init/heroic $HOME/.config
	sed -i "s/#NAME/$USER/" $HOME/.config/heroic/config.json
fi

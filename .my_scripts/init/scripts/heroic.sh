#!/bin/bash

# The script will copy the config settings only if the Heroic folder is empty.

if [ ! -d "$HOME/.config/heroic" ]; then
	cp -r $HOME/.my_scripts/init/user/heroic $HOME/.config
	sed -i "s/#NAME/$USER/" $HOME/.config/heroic/config.json
fi

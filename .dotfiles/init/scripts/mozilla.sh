#!/bin/bash

# Only copies if config folders doesn't exist

# Optimized Thunderbird profile
if [ ! -d "$HOME/.thunderbird" ]; then
    cp -r "$SCRIPT_DIR/user/.thunderbird" "$HOME/.thunderbird"
fi

# Optimized Firefox profile
if [ ! -d "$HOME/.mozilla" ]; then 
    cp -r $SCRIPT_DIR/user/.mozilla ~/.mozilla;
	sed -i "s|/home/henrik|$HOME|g" $HOME/.mozilla/firefox/5twvy6h9.default-release/prefs.js
fi

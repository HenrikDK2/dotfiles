#!/bin/bash

# Only copies if config folders doesn't exist

# Optimized Thunderbird profile
if [ ! -d "$HOME/.thunderbird" ]; then
    cp -r "$HOME/.my_scripts/init/user/.thunderbird" "$HOME/.thunderbird"
fi

# Optimized Firefox profile
if [ ! -d "$HOME/.mozilla" ]; then 
    cp -r ~/.my_scripts/init/user/.mozilla ~/.mozilla;
	sed -i "s|/home/henrik|$HOME|g" $HOME/.mozilla/firefox/vem3poti.dev-edition-default/extensions.json
	sed -i "s|/home/henrik|$HOME|g" $HOME/.mozilla/firefox/vem3poti.dev-edition-default/prefs.js
    cp -r ~/.mozilla/firefox/vem3poti.dev-edition-default ~/.mozilla/firefox/vem3poti.default-release; 
	cp -r ~/.mozilla/firefox/vem3poti.dev-edition-default ~/.mozilla/firefox/vem3poti.default-nightly; 
fi

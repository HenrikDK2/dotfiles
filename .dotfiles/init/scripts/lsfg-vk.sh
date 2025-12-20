#!/bin/bash

# Remember to use lsfg-vk config ui
# You might have to restart Steam/Heroic after making changes to config

mkdir -pv $HOME/.config/lsfg-vk

# Heroic Games Launcher
flatpak override --user --filesystem=$HOME/.config/lsfg-vk:rw com.heroicgameslauncher.hgl
flatpak override --user --env=LSFG_CONFIG=$HOME/.config/lsfg-vk/conf.toml com.heroicgameslauncher.hgl

# Steam
flatpak override --user --filesystem=$HOME/.config/lsfg-vk:rw com.valvesoftware.Steam
flatpak override --user --env=LSFG_CONFIG=$HOME/.config/lsfg-vk/conf.toml com.valvesoftware.Steam


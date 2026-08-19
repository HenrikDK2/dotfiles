#!/bin/bash

# Theme
gsettings set org.gnome.desktop.interface gtk-theme "Nordic-darker"
gsettings set org.gnome.desktop.interface icon-theme 'Nordic-Folders'
gsettings set org.gnome.desktop.wm.preferences theme "Nordic-darker"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
gsettings set org.gnome.desktop.interface cursor-theme "Sunity-cursors"

# Terminal
gsettings set org.cinnamon.desktop.default-applications.terminal exec alacritty

# Nemo
gsettings set org.nemo.preferences executable-text-activation 'display'

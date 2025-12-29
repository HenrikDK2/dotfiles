#!/bin/bash

if ! pgrep -x rofi; then
	export FLATPAK_GL_DRIVERS=mesa-git
	XDG_DATA_DIRS="/usr/local/share:/usr/share:$HOME/.local/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share" rofi -theme ./styles/theme.rasi -show drun
fi

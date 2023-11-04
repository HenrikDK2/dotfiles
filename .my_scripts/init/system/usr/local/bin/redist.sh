#!/bin/bash

export WINEPREFIX="$STEAM_COMPAT_DATA_PATH"

if [ ! -f "./redist-done" ]; then
	notify-send "Installing dlls to new prefix"
	winetricks -q --force vcrun2022 dotnet48 version d3dcompiler_47
	touch "redist-done"
fi

exec "$@" &
exit 0

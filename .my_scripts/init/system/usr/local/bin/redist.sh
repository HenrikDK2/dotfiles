#!/bin/bash

export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"

REDIST_FILE="$WINEPREFIX/redist-done"
PACKAGES="vcrun2022 dotnet48 version d3dcompiler_47"

if [ ! -f "$REDIST_FILE" ]; then
	notify-send -u low "Installing DLLs to new prefix"
	winetricks -q --force $PACKAGES
	touch "$REDIST_FILE"
fi

exec "$@" &

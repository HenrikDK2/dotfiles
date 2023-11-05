#!/bin/bash

if [ -z "$WINEPREFIX" ] && [ ! -z "$STEAM_COMPAT_DATA_PATH" ]; then
	export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"
else
	export WINEPREFIX="$WINEPREFIX/pfx"
fi

REDIST_FILE="$WINEPREFIX/redist-done"
PACKAGES="vcrun2022 dotnet48 version d3dcompiler_47"

if [ ! -f "$REDIST_FILE" ]; then
	notify-send -u low "Installing DLLs to new prefix"
	winetricks -q --force $PACKAGES
	touch "$REDIST_FILE"
fi

exec "$@" &

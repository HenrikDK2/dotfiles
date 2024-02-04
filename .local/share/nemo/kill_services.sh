#!/bin/bash

if [ "$1" != "gamemode" ]; then
	while pgrep -x "nemo" > /dev/null; do
	    sleep 1
	done
fi

systemctl --user stop gvfs-daemon
systemctl --user stop gvfs-mtp-volume-monitor
systemctl --user stop gvfs-udisks2-volume-monitor
systemctl --user stop gvfs-afc-volume-monitor
systemctl --user stop gvfs-goa-volume-monitor
systemctl --user stop gvfs-gphoto2-volume-monitor
systemctl --user stop gvfs-metadata

#!/bin/bash

if ! pgrep -x "nemo" > /dev/null; then
	systemctl --user stop gvfs-daemon
	systemctl --user stop gvfs-mtp-volume-monitor
	systemctl --user stop gvfs-udisks2-volume-monitor
	systemctl --user stop gvfs-afc-volume-monitor
	systemctl --user stop gvfs-goa-volume-monitor
	systemctl --user stop gvfs-gphoto2-volume-monitor
	systemctl --user stop gvfs-metadata
fi


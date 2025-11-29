#!/bin/bash

stop_service() {
	if systemctl --user is-active --quiet $1; then
		systemctl --user stop $1
	fi
}

if ! pgrep -x "nemo" > /dev/null; then
	stop_service gvfs-daemon
	stop_service gvfs-mtp-volume-monitor
	stop_service gvfs-udisks2-volume-monitor
	stop_service gvfs-afc-volume-monitor
	stop_service gvfs-goa-volume-monitor
	stop_service gvfs-gphoto2-volume-monitor
	stop_service gvfs-metadata
	killall gvfsd gvfsd-fuse
fi


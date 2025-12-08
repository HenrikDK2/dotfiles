#!/bin/bash

DIR="/etc/systemd/system/getty@tty1.service.d"
FILE="$DIR/autologin.conf"

if [ ! -f "$FILE" ]; then
	sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
	printf "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin %s --noclear --skip-login --noissue %%I \$TERM\n" "$USERNAME" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf
	systemctl --user mask gnome-keyring-daemon.service gnome-keyring-daemon.socket
fi

#!/bin/bash

DIR="/etc/systemd/system/getty@tty1.service.d"
FILE="$DIR/autologin.conf"
USER=$(whoami)

if [ ! -f "$FILE" ]; then
	clear_screen
	printf "Do you want to setup automatic login at boot?"

	if confirm; then
		sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
		printf "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin %s --noclear --skip-login --noissue %%I \$TERM\n" "$USER" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf
		systemctl --user mask gnome-keyring-daemon.service
		systemctl --user mask gnome-keyring-daemon.socket
	fi
fi

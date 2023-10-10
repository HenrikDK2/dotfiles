#!/bin/sh

export lock_screen="/usr/local/bin/lock_screen.sh"

swayidle -w \
	timeout 300 $lock_screen \
	timeout 600 'swaymsg "output * power off"' \
		resume 'swaymsg "output * power on"' \
	before-sleep $lock_screen

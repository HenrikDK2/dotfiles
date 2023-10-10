#!/bin/bash

config="-C ~/.config/swaylock/config"

swayidle -w \
	timeout 300 "swaylock $config" \
	timeout 600 'swaymsg "output * power off"' \
		resume 'swaymsg "output * power on"' \
	before-sleep "swaylock $config"

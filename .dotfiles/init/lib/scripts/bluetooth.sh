#!/bin/bash

if [ ! -z "$(ls -A /sys/class/bluetooth/)" ]; then
	systemctl enable bluetooth.service
fi

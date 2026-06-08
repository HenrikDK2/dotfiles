#!/bin/bash

USER=$(id -nu "$PKEXEC_UID")
HOME="/home/$USER"

echo "===> Rotating journal logs..."
journalctl --rotate
echo "===> Vacuuming old journal logs..."
journalctl --vacuum-time=1s
echo "===> Initiating soft reboot..."

/usr/bin/systemctl soft-reboot

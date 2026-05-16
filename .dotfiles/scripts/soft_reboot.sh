#!/bin/bash

USER=$(id -nu "$PKEXEC_UID")
HOME="/home/$USER"

echo "===> Rotating journal logs..."
journalctl --rotate
echo "===> Vacuuming old journal logs..."
journalctl --vacuum-time=1s
echo "===> Initiating soft reboot..."

# To avoid audit script from error spamming me
# Because of systemctl soft reboot
mkdir -p $HOME/.cache/audit
touch $HOME/.cache/audit/soft_reboot

/usr/bin/systemctl soft-reboot

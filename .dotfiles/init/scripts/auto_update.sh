#!/bin/bash

# Ensure files have correct permissions
chmod 700 /usr/local/bin/update.sh
chown root:root /usr/local/bin/update.sh

chmod 600 /etc/systemd/system/auto-update.service
chmod 600 /etc/systemd/system/auto-update.timer
chown root:root /etc/systemd/system/auto-update.{service,timer}

# Enable timers
systemctl enable auto-update.timer

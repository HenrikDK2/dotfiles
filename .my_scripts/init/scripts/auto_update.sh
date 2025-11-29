#!/bin/bash

# Ensure files have correct permissions
sudo chmod 700 /usr/local/bin/update.sh
sudo chown root:root /usr/local/bin/update.sh

sudo chmod 600 /etc/systemd/system/auto-update.service
sudo chmod 600 /etc/systemd/system/auto-update.timer
sudo chown root:root /etc/systemd/system/auto-update.{service,timer}

# Enable timers
sudo systemctl enable auto-update.timer
#!/bin/bash

separator "Configuring automatic updates..."
sudo cp -f /usr/share/dnf5/dnf5-plugins/automatic.conf /etc/dnf/automatic.conf
sudo sed -i 's/^apply_updates =.*/apply_updates = yes/' /etc/dnf/automatic.conf

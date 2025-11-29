#!/bin/bash

# Ask if you want to install any of the optional packages
source "$HOME/.my_scripts/init/scripts/optional_packages.sh"

# GPU drivers
auto_install "${gpu_packages[@]}"

# Install packages
auto_install "${packages[@]}"

# System services
sudo systemctl enable avahi-daemon cups ufw dnsmasq gameboost cap_sys_nice pacman-remove-db-lock system-tuning unmask-upower denyhosts.timer fstrim.timer clean-cache.timer
sudo systemctl mask systemd-userdbd systemd-resolved systemd-userdbd.socket accounts-daemon rtkit-daemon ldconfig connman-vpn

# User services
systemctl --user enable wireplumber psd
systemctl --user mask at-spi-dbus-bus

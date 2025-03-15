#!/bin/bash

# Ask if you want to install any of the optional packages
source "$HOME/.my_scripts/init/scripts/optional_packages.sh"

# GPU drivers
yay -S "${gpu_packages[@]}" --needed --ask 4

# Install packages
yay -S "${packages[@]}" --needed --ask 4

# Enable required services
sudo systemctl enable cups ufw dnsmasq denyhosts gameboost cap_sys_nice fstrim.timer clean-cache.timer
systemctl --user enable wireplumber

# Mask unused services
systemctl --user mask at-spi-dbus-bus
sudo systemctl mask systemd-userdbd systemd-userdbd.socket accounts-daemon rtkit-daemon ldconfig upower systemd-resolved connman-vpn

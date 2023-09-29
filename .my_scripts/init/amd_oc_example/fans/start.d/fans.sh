#!/bin/bash

# Copy start.d folder with script in /usr/local/bin/gamemode

echo "1" > /sys/class/drm/card0/device/hwmon/hwmon2/pwm1_enable
echo "155" > /sys/class/drm/card0/device/hwmon/hwmon2/pwm1




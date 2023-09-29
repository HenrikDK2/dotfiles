#!/bin/bash

# Copy exit.d folder with script in /usr/local/bin/gamemode

GPU_CARD=""
HWMON=""

if [ -e /sys/class/drm/card0 ]; then
    GPU_CARD="card0"
elif [ -e /sys/class/drm/card1 ]; then
    GPU_CARD="card1"
fi

if [ -e /sys/class/drm/card$GPU_CARD/device/hwmon/hwmon1 ]; then
    HWMON="hwmon1"
elif [ -e /sys/class/drm/card$GPU_CARD/device/hwmon/hwmon2 ]; then
    HWMON="hwmon2"
fi

echo "2" > /sys/class/drm/$GPU_CARD/device/hwmon/$HWMON/pwm1_enablet

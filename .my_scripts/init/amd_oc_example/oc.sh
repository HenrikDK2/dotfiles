#!/bin/sh

# CHANGE OC VALUES BEFORE RUNNING SCRIPT, THIS IS JUST AN EXAMPLE FILE

# Some changes might be needed for different generations of AMD GPU, however this works on my RX 5700XT.
# Run this as a simple service script at boot, or through some other means.

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

# Core, memory, voltage curve, and power limit
echo "s 1 2120" > "/sys/class/drm/$GPU_CARD/device/pp_od_clk_voltage"
echo "m 1 885" > "/sys/class/drm/$GPU_CARD/device/pp_od_clk_voltage"
echo "vc 1 1450 890" > "/sys/class/drm/$GPU_CARD/device/pp_od_clk_voltage"
echo "vc 2 2120 1200" > "/sys/class/drm/$GPU_CARD/device/pp_od_clk_voltage"
echo "300000000" > "/sys/class/drm/$GPU_CARD/device/hwmon/$HWMON/power1_cap"
echo "c" > "/sys/class/drm/$GPU_CARD/device/pp_od_clk_voltage"

exit 0

#!/bin/sh

# CHANGE OC VALUES BEFORE RUNNING SCRIPT, THIS IS JUST AN EXAMPLE FILE FOR MY CURRENT OC!

# Some changes might be needed for different generations of AMD GPU, however this works on RDNA3.
# Run this as a simple service script at boot, or through some other means.

if [ -e /sys/class/drm/card0 ]; then
    GPU_CARD="card0"
elif [ -e /sys/class/drm/card1 ]; then
    GPU_CARD="card1"
fi

if [ -e /sys/class/drm/$GPU_CARD/device/hwmon/hwmon1 ]; then
    HWMON="hwmon1"
elif [ -e /sys/class/drm/$GPU_CARD/device/hwmon/hwmon2 ]; then
    HWMON="hwmon2"
fi

PP_OD_CLK_VOLTAGE="/sys/class/drm/$GPU_CARD/device/pp_od_clk_voltage"
POWER_CAP="/sys/class/drm/$GPU_CARD/device/hwmon/$HWMON/power1_cap"

# Voltage offset
echo "vo -60" > $PP_OD_CLK_VOLTAGE

# Max core clock
echo "s 1 3100" > $PP_OD_CLK_VOLTAGE

# Max memory clock
echo "m 1 1330" > $PP_OD_CLK_VOLTAGE

# Powerlimit (350W)
echo "350000000" > $POWER_CAP

# Apply settings
echo "c" > $PP_OD_CLK_VOLTAGE

exit 0

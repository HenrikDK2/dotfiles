#!/bin/sh

# CHANGE OC VARIABLE VALUES BEFORE RUNNING SCRIPT, THIS IS JUST AN EXAMPLE FILE FOR MY CURRENT OC!
# Some changes might be needed for different generations of AMD GPU, however this works on RDNA3.

voltage_offset="-30"
core_clock="2950"
memory_clock="1300"
powerlimit="327" # Watts

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
echo "vo $voltage_offset" > $PP_OD_CLK_VOLTAGE

# Core clock
echo "s 1 $core_clock" > $PP_OD_CLK_VOLTAGE

# Memory clock
echo "m 1 $memory_clock" > $PP_OD_CLK_VOLTAGE

# Powerlimit (327W)
#echo "$powerlimit" > $POWER_CAP

# Apply settings
echo "c" > $PP_OD_CLK_VOLTAGE

# Hacky fix to solve memory clock sometimes getting stock
sleep 5
memory_clock=$((memory_clock + 1))
echo "m 1 $memory_clock" > $PP_OD_CLK_VOLTAGE
echo "c" > $PP_OD_CLK_VOLTAGE

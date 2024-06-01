#!/bin/sh

# CHANGE OC VARIABLE VALUES BEFORE RUNNING SCRIPT, THIS IS JUST AN EXAMPLE FILE FOR MY CURRENT OC!
# Some changes might be needed for different generations of AMD GPU, however this works on RDNA3.

VOLTAGE_OFFSET="-30"
CORE_CLOCK="2950"
MEMORY_CLOCK="1300"
MAX_WATTS_POWERLIMIT="327" # Watts

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

GPU="/sys/class/drm/$GPU_CARD/device"
PP_OD_CLK_VOLTAGE="$GPU/pp_od_clk_voltage"
POWER_CAP="$GPU/hwmon/$HWMON/power1_cap"
CURRENT_MEMORY_SPEED=$(grep '*' "$GPU/pp_dpm_mclk" | awk '{print $2}')

# Voltage offset
echo "vo $VOLTAGE_OFFSET" > $PP_OD_CLK_VOLTAGE

# Core clock
echo "s 1 $CORE_CLOCK" > $PP_OD_CLK_VOLTAGE

# Memory clock
echo "m 1 $MEMORY_CLOCK" > $PP_OD_CLK_VOLTAGE

# Powerlimit
#echo "$(($MAX_WATTS_POWERLIMIT * 1000000))" > $POWER_CAP

# Apply settings
echo "c" > $PP_OD_CLK_VOLTAGE

# Fix memory stuck
while true; do

	# Only the default memory speeds are present in pp_dpm_mclk, if the value is empty that means the new memory clock is applied.
	# However if not empty, it will try to fix the stuck memory speed. 
	if [[ "$CURRENT_MEMORY_SPEED" != "" ]]; then
		echo "m 1 $(($MEMORY_CLOCK + 1))" > $PP_OD_CLK_VOLTAGE
		echo "c" > $PP_OD_CLK_VOLTAGE
		sleep 5
		echo "m 1 $new_MEMORY_CLOCK" > $PP_OD_CLK_VOLTAGE
		echo "c" > $PP_OD_CLK_VOLTAGE
	fi

	sleep 300
done

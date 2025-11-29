#!/bin/sh

# Load configuration from amd-overclock.conf
CONFIG_FILE="/etc/amd-overclock.conf"

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file $CONFIG_FILE not found."
    exit 1
fi

# Source the config file
. "$CONFIG_FILE"

# Check if at least one variable is set
if [ -z "$VOLTAGE_OFFSET" ] && [ -z "$CORE_CLOCK" ] && [ -z "$MEMORY_CLOCK" ] && [ -z "$MAX_WATTS_POWERLIMIT" ]; then
	echo "Error: Configuration file $CONFIG_FILE should have at least one modified value."
    exit 1
fi

GPU=$(lspci | awk '/VGA|3D/{print "/sys/bus/pci/devices/0000:"$1}')
HWMON=$(basename "$(find "$GPU/hwmon" -mindepth 1 -maxdepth 1 -name "hwmon*" -type d | head -n 1)" 2>/dev/null)

PP_OD_CLK_VOLTAGE="$GPU/pp_od_clk_voltage"
POWER_CAP="$GPU/hwmon/$HWMON/power1_cap"

# Set voltage offset
if [ ! -z "$VOLTAGE_OFFSET" ]; then
    echo "Setting voltage offset to $VOLTAGE_OFFSET mV."
    echo "vo $VOLTAGE_OFFSET" > $PP_OD_CLK_VOLTAGE
fi

# Set core clock
if [ ! -z "$CORE_CLOCK" ]; then
    echo "Setting core clock to $CORE_CLOCK MHz."
    echo "s 1 $CORE_CLOCK" > $PP_OD_CLK_VOLTAGE
fi

# Set memory clock
if [ ! -z "$MEMORY_CLOCK" ]; then
    echo "Setting memory clock to $MEMORY_CLOCK MHz."
    echo "m 1 $MEMORY_CLOCK" > $PP_OD_CLK_VOLTAGE
fi

# Set power limit
if [ ! -z "$MAX_WATTS_POWERLIMIT" ]; then
    echo "Setting maximum power limit to $MAX_WATTS_POWERLIMIT Watts."
    echo "$(($MAX_WATTS_POWERLIMIT * 1000000))" > $POWER_CAP
fi

# Apply settings
echo "Applying settings."
echo "c" > $PP_OD_CLK_VOLTAGE

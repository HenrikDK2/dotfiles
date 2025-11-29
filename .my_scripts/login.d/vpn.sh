#!/bin/bash

# Check for Private Internet Access (PIA)
if command -v piactl &> /dev/null; then
    VPN_STATUS=$(piactl get connectionstate)

    # If not connected, attempt to connect
    if [ "$VPN_STATUS" != "Connected" ]; then
    	piactl background enable
        piactl connect
    fi

# Check for Mullvad VPN
elif command -v mullvad &> /dev/null; then
    mullvad connect
fi

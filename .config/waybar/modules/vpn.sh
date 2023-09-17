#!/bin/bash

connected(){
	echo '{"text": "Connected", "tooltip": "VPN status: connected", "class": "connected", "percentage": 100}'
	exit 0
}

# Check if Mullvad VPN is active based on the status
if [[ "$(mullvad status)" == *"Connected to"* ]]; then connected; fi

# Check if NordVPN is active
if nordvpn status | grep -q "Status: Connected"; then connected fi

# Check if the tun0 interface exists
if [ -d /proc/sys/net/ipv4/conf/tun0 ]; then connected; fi

# Check if the ppp0 interface exists
if [ -d /proc/sys/net/ipv4/conf/ppp0 ]; then connected; fi

echo '{"text": "Disconnected", "tooltip": "VPN status: disconnected", "class" :"disconnected", "percentage" :0}'

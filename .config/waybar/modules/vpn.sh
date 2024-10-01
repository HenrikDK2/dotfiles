#!/bin/bash

connected() {
  tooltip="${1:-VPN status: connected}"
  echo "{\"text\": \"Connected\", \"tooltip\": \"$tooltip\", \"class\": \"connected\", \"percentage\": 100}"
  exit 0
}

# Check if Mullvad VPN is active based on the status
if (mullvad status | grep -q "^Connected to"); then
	connected;
fi

# Check if NordVPN is active
if (nordvpn status | grep -q "Status: Connected"); then
	connected "$(nordvpn status)"
fi

# Check if Private Internet Access (PIA) is active
if (command -v piactl &> /dev/null) && [ "$(piactl get connectionstate)" = "Connected" ]; then
    connected "PIA VPN is connected";
fi

# Check if the tun0 or ppp0 interface exists
if [ -d /proc/sys/net/ipv4/conf/tun0 ] || [ -d /proc/sys/net/ipv4/conf/ppp0 ]; then 
	connected;
fi

echo '{"text": "Disconnected", "tooltip": "VPN status: disconnected", "class" :"disconnected", "percentage" :0}'

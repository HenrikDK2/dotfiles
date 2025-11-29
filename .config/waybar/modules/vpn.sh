#!/bin/bash

connected() {
  raw_country="${1:-}"
  tooltip="${2:-VPN status: connected}"

  # Capitalize first letter (handles multi-word countries too)
  if [ -n "$raw_country" ]; then
    country=$(echo "$raw_country" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')
    echo "{\"text\": \"$country\", \"tooltip\": \"$tooltip\", \"class\": \"connected\", \"percentage\": 100}"
  else
    echo "{\"text\": \"Connected\", \"tooltip\": \"$tooltip\", \"class\": \"connected\", \"percentage\": 100}"
  fi
  
  exit 0
}

# Check if Mullvad VPN is active
if command -v mullvad &> /dev/null && mullvad status | grep -q "^Connected to"; then
    country=$(mullvad status | grep -oP 'Connected to \K.*?(?=\.)')
    connected "$country"
fi

# Check if NordVPN is active
if command -v nordvpn &> /dev/null && nordvpn status | grep -q "Status: Connected"; then
    country=$(nordvpn status | grep -oP 'Country:\s*\K.*')
    tooltip=$(nordvpn status)
    connected "$country" "$tooltip"
fi

# Check if Private Internet Access (PIA) is active
if command -v piactl &> /dev/null && [ "$(piactl get connectionstate)" = "Connected" ]; then
    country=$(piactl get region | sed 's/-/ /g')
    connected "$country" "PIA VPN is connected to $country"
fi

# Check if the tun0 or ppp0 interface exists
if [ -d /proc/sys/net/ipv4/conf/tun0 ] || [ -d /proc/sys/net/ipv4/conf/ppp0 ]; then 
    connected
fi

# Show disconnected text
echo '{"text": "Disconnected", "tooltip": "VPN status: disconnected", "class" :"disconnected", "percentage" :0}'

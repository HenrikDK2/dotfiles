#!/bin/bash
CACHE_DIR="/tmp/vpn-monitor-$USER"
IP_FILE="$CACHE_DIR/last_ip"
COUNTRY_FILE="$CACHE_DIR/last_country"
mkdir -p "$CACHE_DIR"

# Read cached IP and country
CACHED_IP=""
CACHED_COUNTRY=""
[ -f "$IP_FILE" ] && CACHED_IP=$(cat "$IP_FILE")
[ -f "$COUNTRY_FILE" ] && CACHED_COUNTRY=$(cat "$COUNTRY_FILE")

# Get current IP from VPN interface or default route
CURRENT_IP=""

# First, try to get IP from VPN interfaces (tun0, ppp0, wg0)
for iface in tun0 ppp0 wg0; do
    if [ -d "/proc/sys/net/ipv4/conf/$iface" ]; then
        CURRENT_IP=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        [ -n "$CURRENT_IP" ] && break
    fi
done

# If no VPN interface found, get IP from default route interface
if [ -z "$CURRENT_IP" ]; then
    DEFAULT_IFACE=$(ip route | grep '^default' | head -1 | grep -oP '(?<=dev\s)\S+')
    if [ -n "$DEFAULT_IFACE" ]; then
        CURRENT_IP=$(ip -4 addr show "$DEFAULT_IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    fi
fi

# Check if IP has changed
IP_CHANGED=false
if [ -n "$CURRENT_IP" ] && [ "$CURRENT_IP" != "$CACHED_IP" ]; then
    IP_CHANGED=true
fi

# If IP hasn't changed and we have cached country, use it
if [ "$IP_CHANGED" = false ] && [ -n "$CACHED_COUNTRY" ]; then
    COUNTRY="$CACHED_COUNTRY"
    VPN_ACTIVE=true
else
    # IP changed or no cache - check VPN status and get location
    COUNTRY=""
    VPN_ACTIVE=false
    
    # Check if Mullvad VPN is active
    if command -v mullvad &> /dev/null && mullvad status | grep -q "^Connected to"; then
        MULLVAD_COUNTRY=$(mullvad status | grep -oP 'Connected to \K.*?(?=\.)')
        COUNTRY="${MULLVAD_COUNTRY:-$COUNTRY}"
        VPN_ACTIVE=true
    fi
    
    # Check if NordVPN is active
    if command -v nordvpn &> /dev/null && nordvpn status | grep -q "Status: Connected"; then
        NORD_COUNTRY=$(nordvpn status | grep -oP 'Country:\s*\K.*')
        COUNTRY="${NORD_COUNTRY:-$COUNTRY}"
        VPN_ACTIVE=true
    fi
    
    # Check if Private Internet Access (PIA) is active
    if command -v piactl &> /dev/null && [ "$(piactl get connectionstate)" = "Connected" ]; then
        PIA_COUNTRY=$(piactl get region | sed 's/-/ /g')
        COUNTRY="${PIA_COUNTRY:-$COUNTRY}"
        VPN_ACTIVE=true
    fi
    
    # Check if OpenVPN connection exists via nmcli
    if command -v nmcli &> /dev/null; then
        if nmcli -t -f TYPE,STATE connection show --active | grep -q '^vpn:activated'; then
            VPN_ACTIVE=true
        fi
    fi
    
    # Check if the tun0, ppp0, or wg0 interface exists (fallback)
    if [ -d /proc/sys/net/ipv4/conf/tun0 ] || [ -d /proc/sys/net/ipv4/conf/ppp0 ] || [ -d /proc/sys/net/ipv4/conf/wg0 ]; then 
        VPN_ACTIVE=true
    fi
    
    # If no country from VPN clients and IP has changed, lookup via geolocation
    if [ "$VPN_ACTIVE" = true ] && [ -z "$COUNTRY" ] && [ "$IP_CHANGED" = true ]; then
        # Get public IP for geolocation
        PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
        if [ -n "$PUBLIC_IP" ]; then
            LOCATION=$(curl -s --max-time 5 "https://ipapi.co/${PUBLIC_IP}/json/" 2>/dev/null)
            COUNTRY=$(echo "$LOCATION" | grep -oP '"country_name":\s*"\K[^"]+')
        fi
    fi
    
    # Save to cache if we have country and VPN is active
    if [ "$VPN_ACTIVE" = true ] && [ -n "$COUNTRY" ] && [ -n "$CURRENT_IP" ]; then
        echo "$CURRENT_IP" > "$IP_FILE"
        echo "$COUNTRY" > "$COUNTRY_FILE"
    elif [ "$VPN_ACTIVE" = false ]; then
        # Clear cache if VPN is disconnected
        rm -f "$IP_FILE" "$COUNTRY_FILE"
    fi
fi

# Output result
if [ "$VPN_ACTIVE" = true ]; then
    if [ -n "$COUNTRY" ]; then
        # Capitalize country name
        COUNTRY=$(echo "$COUNTRY" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')
        echo "{\"text\": \"$COUNTRY\", \"tooltip\": \"VPN status: connected\", \"class\": \"connected\", \"percentage\": 100}"
    else
        echo "{\"text\": \"Connected\", \"tooltip\": \"VPN status: connected\", \"class\": \"connected\", \"percentage\": 100}"
    fi
else
    echo '{"text": "Disconnected", "tooltip": "VPN status: disconnected", "class": "disconnected", "percentage": 0}'
fi

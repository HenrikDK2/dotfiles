#!/bin/bash

CACHE_DIR="/tmp/vpn-monitor-$USER"
IP_FILE="$CACHE_DIR/last_ip"
COUNTRY_FILE="$CACHE_DIR/last_country"
mkdir -p "$CACHE_DIR"

# Read cache
[ -f "$IP_FILE" ] && read -r CACHED_IP < "$IP_FILE"
[ -f "$COUNTRY_FILE" ] && read -r CACHED_COUNTRY < "$COUNTRY_FILE"

# Get current IP from VPN interfaces (tun0-9, ppp0-9, wg0-9)
CURRENT_IP=""
for iface in tun{0..9} ppp{0..9} wg{0..9}; do
    [ -d "/sys/class/net/$iface" ] || continue
    CURRENT_IP=$(ip -4 addr show dev "$iface" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
    [ -n "$CURRENT_IP" ] && break
done

# Fallback: default route
if [ -z "$CURRENT_IP" ]; then
    DEFAULT_IFACE=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)
    [ -n "$DEFAULT_IFACE" ] && CURRENT_IP=$(ip -4 addr show dev "$DEFAULT_IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
fi

IP_CHANGED=false
[ "$CURRENT_IP" != "$CACHED_IP" ] && IP_CHANGED=true

VPN_ACTIVE=false
COUNTRY=""

capitalize() { local s="$1"; echo "${s^}"; }

# Check VPN clients only if IP changed or no cached country
if [ "$IP_CHANGED" = true ] || [ -z "$CACHED_COUNTRY" ]; then
    # Mullvad
    if command -v mullvad &>/dev/null; then
        STATUS=$(mullvad status 2>/dev/null)
        [[ $STATUS =~ Connected\ to\ ([^.]+) ]] && COUNTRY="${BASH_REMATCH[1]}" && VPN_ACTIVE=true
    fi

    # NordVPN
    if ! $VPN_ACTIVE && command -v nordvpn &>/dev/null; then
        STATUS=$(nordvpn status 2>/dev/null)
        [[ $STATUS =~ Country:[[:space:]]*(.*) ]] && COUNTRY="${BASH_REMATCH[1]}" && VPN_ACTIVE=true
    fi

    # PIA
    if ! $VPN_ACTIVE && command -v piactl &>/dev/null; then
        [ "$(piactl get connectionstate)" = "Connected" ] && COUNTRY=$(piactl get region | tr '-' ' ') && VPN_ACTIVE=true
    fi

    # NMCLI OpenVPN check
    if ! $VPN_ACTIVE && command -v nmcli &>/dev/null; then
        if nmcli -t -f TYPE,STATE connection show --active | grep -q '^vpn:activated'; then
            VPN_ACTIVE=true
        fi
    fi

    # OpenVPN fallback: any tunX/pppX/wgX interface with IP
    if ! $VPN_ACTIVE; then
        for iface in tun{0..9} ppp{0..9} wg{0..9}; do
            [ -d "/sys/class/net/$iface" ] || continue
            if ip -4 addr show dev "$iface" 2>/dev/null | grep -q "inet "; then
                VPN_ACTIVE=true
                break
            fi
        done
    fi

    # Fetch geolocation if VPN detected but no country
    if $VPN_ACTIVE && [ -z "$COUNTRY" ] && [ "$IP_CHANGED" = true ]; then
        PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
        if [ -n "$PUBLIC_IP" ]; then
            COUNTRY=$(curl -s --max-time 5 "https://ipapi.co/${PUBLIC_IP}/country_name/")
        fi
    fi

    # Update cache
    if $VPN_ACTIVE && [ -n "$COUNTRY" ] && [ -n "$CURRENT_IP" ]; then
        echo "$CURRENT_IP" > "$IP_FILE"
        echo "$COUNTRY" > "$COUNTRY_FILE"
    elif ! $VPN_ACTIVE; then
        rm -f "$IP_FILE" "$COUNTRY_FILE"
    fi
else
    COUNTRY="$CACHED_COUNTRY"
    VPN_ACTIVE=true
fi

# Output JSON
if $VPN_ACTIVE; then
    if [ -n "$COUNTRY" ]; then
        COUNTRY=$(capitalize "$COUNTRY")
        echo "{\"text\": \"$COUNTRY\", \"tooltip\": \"VPN status: connected\", \"class\": \"connected\", \"percentage\": 100}"
    else
        # Fallback text if no country
        echo "{\"text\": \"Connected\", \"tooltip\": \"VPN status: connected\", \"class\": \"connected\", \"percentage\": 100}"
    fi
else
    echo '{"text": "Disconnected", "tooltip": "VPN status: disconnected", "class": "disconnected", "percentage": 0}'
fi

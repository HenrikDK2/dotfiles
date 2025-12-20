#!/bin/bash

# Configuration
CACHE_DIR="/tmp/vpn-monitor-$USER"
IP_FILE="$CACHE_DIR/last_ip"
COUNTRY_FILE="$CACHE_DIR/last_country"

# Global variables
CACHED_IP=""
CACHED_COUNTRY=""
CURRENT_IP=""
VPN_ACTIVE=false
COUNTRY=""

function init_cache() {
    mkdir -p "$CACHE_DIR"
}

function read_cache() {
    [ -f "$IP_FILE" ] && read -r CACHED_IP < "$IP_FILE"
    [ -f "$COUNTRY_FILE" ] && read -r CACHED_COUNTRY < "$COUNTRY_FILE"
}

function get_vpn_interface_ip() {
    local ip=""
    for iface in tun{0..9} ppp{0..9} wg{0..9}; do
        [ -d "/sys/class/net/$iface" ] || continue
        ip=$(ip -4 addr show dev "$iface" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
        [ -n "$ip" ] && echo "$ip" && return 0
    done
    return 1
}

function get_default_interface_ip() {
    local default_iface=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)
    if [ -n "$default_iface" ]; then
        ip -4 addr show dev "$default_iface" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1
    fi
}

function get_current_ip() {
    CURRENT_IP=$(get_vpn_interface_ip)
    [ -z "$CURRENT_IP" ] && CURRENT_IP=$(get_default_interface_ip)
}

function check_ip_changed() {
    [ "$CURRENT_IP" != "$CACHED_IP" ]
}

function capitalize() {
    local s="$1"
    echo "${s^}"
}

function check_mullvad() {
    if command -v mullvad &>/dev/null; then
        local status=$(mullvad status 2>/dev/null)
        if [[ $status =~ Connected\ to\ ([^.]+) ]]; then
            COUNTRY="${BASH_REMATCH[1]}"
            return 0
        fi
    fi
    return 1
}

function check_nordvpn() {
    if command -v nordvpn &>/dev/null; then
        local status=$(nordvpn status 2>/dev/null)
        if [[ $status =~ Country:[[:space:]]*(.*) ]]; then
            COUNTRY="${BASH_REMATCH[1]}"
            return 0
        fi
    fi
    return 1
}

function check_pia() {
    if command -v piactl &>/dev/null; then
        if [ "$(piactl get connectionstate)" = "Connected" ]; then
            COUNTRY=$(piactl get region | tr '-' ' ')
            return 0
        fi
    fi
    return 1
}

function check_nmcli() {
    if command -v nmcli &>/dev/null; then
        if nmcli -t -f TYPE,STATE connection show --active | grep -q '^vpn:activated'; then
            return 0
        fi
    fi
    return 1
}

function check_generic_vpn_interface() {
    for iface in tun{0..9} ppp{0..9} wg{0..9}; do
        [ -d "/sys/class/net/$iface" ] || continue
        if ip -4 addr show dev "$iface" 2>/dev/null | grep -q "inet "; then
            return 0
        fi
    done
    return 1
}

function fetch_geolocation() {
    local public_ip=$(curl -s --max-time 5 https://api.ipify.org)
    
    if [ -z "$public_ip" ]; then
        return 1
    fi
    
    local geo_response=$(curl -s --max-time 5 "https://ipapi.co/${public_ip}/json/")
    if command -v jq &>/dev/null && [ -n "$geo_response" ]; then
        local has_error=$(echo "$geo_response" | jq -r '.error // false')
        if [ "$has_error" = "false" ]; then
            COUNTRY=$(echo "$geo_response" | jq -r '.country_name // empty')
            [ -n "$COUNTRY" ] && return 0
        fi
    fi
    
    geo_response=$(curl -s --max-time 5 "https://ipwho.is/${public_ip}")
    if command -v jq &>/dev/null && [ -n "$geo_response" ]; then
        local success=$(echo "$geo_response" | jq -r '.success // false')
        if [ "$success" = "true" ]; then
            COUNTRY=$(echo "$geo_response" | jq -r '.country // empty')
            [ -n "$COUNTRY" ] && return 0
        fi
    fi
    
    COUNTRY="Connected"
    return 0
}

function check_vpn_status() {
    VPN_ACTIVE=false
    COUNTRY=""
    
    check_mullvad && VPN_ACTIVE=true && return 0
    check_nordvpn && VPN_ACTIVE=true && return 0
    check_pia && VPN_ACTIVE=true && return 0
    check_nmcli && VPN_ACTIVE=true && return 0
    check_generic_vpn_interface && VPN_ACTIVE=true && return 0
    
    return 1
}

function update_cache() {
    if $VPN_ACTIVE && [ -n "$COUNTRY" ] && [ -n "$CURRENT_IP" ]; then
        echo "$CURRENT_IP" > "$IP_FILE"
        echo "$COUNTRY" > "$COUNTRY_FILE"
    elif ! $VPN_ACTIVE; then
        rm -f "$IP_FILE" "$COUNTRY_FILE"
    fi
}

function output_json() {
    if $VPN_ACTIVE; then
        local display_country="${COUNTRY:-Connected}"
        display_country=$(capitalize "$display_country")
        echo "{\"text\": \"$display_country\", \"tooltip\": \"VPN status: connected\", \"class\": \"connected\", \"percentage\": 100}"
    else
        echo '{"text": "Disconnected", "tooltip": "VPN status: disconnected", "class": "disconnected", "percentage": 0}'
    fi
}

function main() {
    init_cache
    read_cache
    get_current_ip
    
    local ip_changed=false
    check_ip_changed && ip_changed=true
    
    if [ "$ip_changed" = true ] || [ -z "$CACHED_COUNTRY" ]; then
        check_vpn_status
        
        if $VPN_ACTIVE && [ -z "$COUNTRY" ] && [ "$ip_changed" = true ]; then
            fetch_geolocation
        fi
        
        update_cache
    else
        COUNTRY="$CACHED_COUNTRY"
        VPN_ACTIVE=true
    fi
    
    output_json
}

main

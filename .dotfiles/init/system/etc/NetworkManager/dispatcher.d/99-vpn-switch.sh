#!/bin/bash

## Script forces only one VPN connection at a time
## Makes it easier to change server

if [ "$2" = "vpn-up" ]; then
    nmcli -t -f NAME,TYPE connection show --active | \
    grep vpn | cut -d: -f1 | while read vpn; do
        if [ "$vpn" != "$CONNECTION_ID" ]; then
            nmcli connection down "$vpn"
        fi
    done
fi

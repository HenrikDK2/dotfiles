#!/bin/sh

renice -n 20 $$
ionice -c idle -p $$

wget -q --tries=10 --timeout=20 -O - http://google.com > /dev/null

if [[ $? -eq 0 ]]; then
    # Output and combine hosts files
    wget -O "/etc/hosts.deny.new" https://hosts.ubuntu101.co.za/hosts # Ultimate-Hosts-Blacklist
    wget -O - >> "/etc/hosts.deny.new" https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts # StevenBlack hosts
    wget -O - >> "/etc/hosts.deny.new" https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt # lightswitch05 hosts 
    wget -O - >> "/etc/hosts.deny.new" https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt # Blocking Web Browser Bitcoin Mining
    wget -O - >> "/etc/hosts.deny.new" https://blocklistproject.github.io/Lists/ads.txt # Blocklist project (ads)

    # Remove duplicates and comments
    sed -i '/^[[:blank:]]*#/d;s/[[:blank:]]*#.*//' /etc/hosts.deny.new
    awk -i inplace '!seen[$0]++' /etc/hosts.deny.new
    sed -i "7d" /etc/hosts.deny.new

    # Replace current hosts.deny with new one
    if [ "$(grep -c ^ /etc/hosts.deny.new)" -ge "100" ]; then
        rm -f /etc/hosts.deny
        mv /etc/hosts.deny.new /etc/hosts.deny
        systemctl restart dnsmasq.service
        exit 0
    fi
fi

rm -f /etc/hosts.deny.new
exit 1

#!/bin/sh

renice -n 20 $$
ionice -c idle -p $$

wget -q --tries=10 --timeout=20 -O - http://google.com > /dev/null

if [[ $? -eq 0 ]]; then
    wget --limit-rate=200k  -O "/etc/hosts.deny.new" https://hosts.ubuntu101.co.za/hosts
    if [ "$(grep -c ^ /etc/hosts.deny.new)" -ge "636000" ]; then
        sudo rm /etc/hosts.deny
        mv /etc/hosts.deny.new /etc/hosts.deny
        systemctl restart dnsmasq.service
        exit 0
    fi
fi

exit 1

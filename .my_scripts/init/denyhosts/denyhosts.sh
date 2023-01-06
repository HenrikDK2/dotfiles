#!/bin/sh

add_source(){
	wget -O - >> "/etc/hosts.deny.new" $1
}

update_hosts(){
    wget -q --tries=10 --timeout=20 -O - http://google.com > /dev/null

    if [[ $? -eq 0 ]]; then
        add_source https://raw.githubusercontent.com/Ultimate-Hosts-Blacklist/Ultimate.Hosts.Blacklist/master/hosts/hosts0
       	add_source https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt
 		add_source https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts
 		add_source https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt
 		add_source https://raw.githubusercontent.com/HexxiumCreations/threat-list/gh-pages/hosts.txt
		add_source https://malware-filter.gitlab.io/malware-filter/phishing-filter-hosts.txt
		add_source https://raw.githubusercontent.com/shreyasminocha/shady-hosts/main/hosts
		
        # Remove comments and duplicates
        sed -i '/^[[:blank:]]*#/d;s/[[:blank:]]*#.*/!d/' /etc/hosts.deny.new
        awk -i inplace '!seen[$0]++' /etc/hosts.deny.new

        # Replace current hosts.deny with new one
        if [ "$(grep -c ^ /etc/hosts.deny.new)" -ge "100" ]; then
            rm -f /etc/hosts.deny
            mv /etc/hosts.deny.new /etc/hosts.deny
            systemctl restart dnsmasq.service
            exit 0
        else
            rm -f /etc/hosts.deny.new
            exit 1
        fi
    else
        sleep 5
        update_hosts
    fi
}

update_hosts

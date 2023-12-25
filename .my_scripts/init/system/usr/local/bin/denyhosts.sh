#!/bin/sh

add_source(){
	if [ -z $2 ]; then
		wget -T 20 -t 1 -O - >> "/tmp/denyhosts.txt" $1
	else
		wget -T 20 -t 1 -O - > "/tmp/denyhoststemp.txt" $1
		sed -i '/^[ \t]*#/d;/^[[:space:]]*$/d' /tmp/denyhoststemp.txt
		sed -i "s/^/$2 /" /tmp/denyhoststemp.txt
		cat /tmp/denyhoststemp.txt | tee -a /tmp/denyhosts.txt
		rm -f /tmp/denyhoststemp.txt
	fi
}

update_hosts(){
    wget -q --tries=10 --timeout=20 -O - http://google.com > /dev/null

    if [[ $? -eq 0 ]]; then
	    add_source https://raw.githubusercontent.com/Ultimate-Hosts-Blacklist/Ultimate.Hosts.Blacklist/master/hosts/hosts0
       	add_source https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
		
        # Remove comments and duplicates
        sed -i '/^[ \t]*#/d;/^[[:space:]]*$/d' /tmp/denyhosts.txt
		sed -i '1,7d' /tmp/denyhosts.txt
		sed -i 's/127.0.0.1[ \t]*/0.0.0.0 /g' /tmp/denyhosts.txt
        awk -i inplace '!seen[$0]++' /tmp/denyhosts.txt

        # Replace current hosts.deny with new one
        if [ "$(grep -c ^ /tmp/denyhosts.txt)" -ge "100" ]; then
            rm -f /etc/hosts.deny
            mv /tmp/denyhosts.txt /etc/hosts.deny
            systemctl restart dnsmasq.service
            exit 0
        else
            rm -f /tmp/denyhosts.txt
            exit 1
        fi
    else
        sleep 5
        update_hosts
    fi
}

update_hosts

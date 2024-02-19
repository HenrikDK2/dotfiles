#!/bin/sh

add_source(){
	if [ -z $2 ]; then
		curl -m 20 --retry 1 -o - "$1" >> "/tmp/denyhosts.txt"
	else
        curl -m 20 --retry 1 -o - "$1" >> "/tmp/denyhoststemp.txt"
		sed -i '/^[ \t]*#/d;/^[[:space:]]*$/d' /tmp/denyhoststemp.txt
		sed -i "s/^/$2 /" /tmp/denyhoststemp.txt
		cat /tmp/denyhoststemp.txt | tee -a /tmp/denyhosts.txt
		rm -f /tmp/denyhoststemp.txt
	fi
}

update_hosts(){
    curl -s --retry 10 --max-time 20 -o /dev/null http://google.com

    if [[ $? -eq 0 ]]; then
	    add_source https://raw.githubusercontent.com/Ultimate-Hosts-Blacklist/Ultimate.Hosts.Blacklist/master/hosts/hosts0
       	add_source https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
		
        # Remove comments and duplicates
        sed -i '/^[ \t]*#/d;/^[[:space:]]*$/d' /tmp/denyhosts.txt
		sed -i '1,7d' /tmp/denyhosts.txt
		sed -i 's/127.0.0.1[ \t]*/0.0.0.0 /g' /tmp/denyhosts.txt
		sed -i '/fe80::1%lo0/d' /tmp/denyhosts.txt
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

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
       	add_source https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt
 		add_source https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts
 		add_source https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt
 		add_source https://raw.githubusercontent.com/HexxiumCreations/threat-list/gh-pages/hosts.txt
		add_source https://raw.githubusercontent.com/shreyasminocha/shady-hosts/main/hosts
		add_source https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts
		add_source https://urlhaus.abuse.ch/downloads/hostfile/
		add_source https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts
		add_source https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser
		add_source https://v.firebog.net/hosts/Prigent-Malware.txt "0.0.0.0"
		add_source https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt "0.0.0.0"
		add_source https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt "0.0.0.0"
		add_source https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt "0.0.0.0" 
		add_source https://phishing.army/download/phishing_army_blocklist_extended.txt "0.0.0.0" 
		add_source https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt "0.0.0.0"
		add_source https://v.firebog.net/hosts/RPiList-Malware.txt "0.0.0.0"
		add_source https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt "0.0.0.0"
		add_source https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts "0.0.0.0"
		add_source https://v.firebog.net/hosts/static/w3kbl.txt "0.0.0.0"
		
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

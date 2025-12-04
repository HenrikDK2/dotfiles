#!/bin/bash

separator "Configuring firewall..."

# Reset firewalld (remove all custom rules and set default zone to public)
sudo firewall-cmd --permanent --delete-all-zones
sudo firewall-cmd --set-default-zone=public
sudo firewall-cmd --reload

# Default policies (firewalld blocks incoming by default in public zone)
# Outgoing is allowed by default in firewalld, so no change needed

# Disable ICMP (ping)
sudo firewall-cmd --permanent --add-icmp-block=echo-request

# Add rules
# HTTPS (global)
sudo firewall-cmd --permanent --add-service=https

# HTTP, CUPS, FTP, LocalSend (LAN only: 192.168.0.0/16)
LAN_SUBNET="192.168.0.0/16"
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$LAN_SUBNET' port protocol='tcp' port='80' accept"
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$LAN_SUBNET' port protocol='tcp' port='631' accept"
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$LAN_SUBNET' port protocol='tcp' port='21' accept"
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$LAN_SUBNET' port protocol='tcp' port='53317' accept"
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$LAN_SUBNET' port protocol='udp' port='53317' accept"

# Reload firewall to apply changes
sudo firewall-cmd --reload

# Disable firewalld logging (firewalld logs to journal; disabling globally is not typical, but we can set log denied to off)
sudo firewall-cmd --set-log-denied=off

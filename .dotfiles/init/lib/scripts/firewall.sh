#!/bin/bash

# Reset UFW
ufw --force reset
chmod 600 /etc/ufw/*.rules
chmod 600 /etc/ufw/*.rules

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Disable ICMP (ping)
sed -i 's/echo-request -j ACCEPT/echo-request -j DROP/' /etc/ufw/before.rules

# Set SSH rule
mkdir -p /etc/ssh/sshd_config.d
echo "Port 1065" | tee /etc/ssh/sshd_config.d/99-port.conf

# Rules
ufw allow 443/tcp # HTTPS (secure web traffic, global)
ufw allow from 192.168.0.0/16 to any port 80 proto tcp # HTTP (web traffic, LAN only)
ufw allow from 192.168.0.0/16 to any port 631 proto tcp # CUPS (network printing, LAN only)
ufw allow from 192.168.0.0/16 to any port 21 proto tcp # FTP (LAN only)
ufw allow from 192.168.0.0/16 to any port 53317 proto tcp     # LocalSend TCP (LAN only)
ufw allow from 192.168.0.0/16 to any port 53317 proto udp     # LocalSend UDP (LAN only)

# Disable logging and enable firewall
ufw logging off
ufw --force enable

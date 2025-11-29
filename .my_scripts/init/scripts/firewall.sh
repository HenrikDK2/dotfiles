#!/bin/bash

# Reset UFW
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Disable ICMP (ping)
sudo sed -i 's/echo-request -j ACCEPT/echo-request -j DROP/' /etc/ufw/before.rules

# Set SSH rule
sudo mkdir -p /etc/ssh/sshd_config.d
echo "Port 1065" | sudo tee /etc/ssh/sshd_config.d/99-port.conf

# Rules
sudo ufw allow 443/tcp # HTTPS (secure web traffic, global)
sudo ufw allow from 192.168.0.0/16 to any port 80 proto tcp # HTTP (web traffic, LAN only)
sudo ufw allow from 192.168.0.0/16 to any port 631 proto tcp # CUPS (network printing, LAN only)
sudo ufw allow from 192.168.0.0/16 to any port 21 proto tcp # FTP (LAN only)
sudo ufw allow from 192.168.0.0/16 to any port 53317 proto tcp     # LocalSend TCP (LAN only)
sudo ufw allow from 192.168.0.0/16 to any port 53317 proto udp     # LocalSend UDP (LAN only)

# Disable logging and enable firewall
sudo ufw logging off
sudo ufw --force enable

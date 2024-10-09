#!/bin/bash

# Enable UFW and add firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo sed -i 's/echo-request -j ACCEPT/echo-request -j DROP/' /etc/ufw/before.rules
echo "Port 1065" | sudo tee /etc/ssh/sshd_config.d/99-port.conf
sudo ufw limit 1065/tcp #SSH
sudo ufw allow 631/tcp #CUPS (printer)
sudo ufw allow ftp/tcp
sudo ufw allow http/tcp
sudo ufw allow https/tcp
sudo ufw logging off
sudo ufw enable

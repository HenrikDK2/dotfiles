#!/bin/bash

# Setup Apparmor
groupadd -r audit
gpasswd -a $USER audit

if ! grep -q '^log_group = audit' /etc/audit/auditd.conf; then
    echo 'log_group = audit' >> /etc/audit/auditd.conf
fi

# Fixes issues with firejail
chown root:root /etc/localtime
chmod 644 /etc/localtime

# Enforce rules
firecfg

# Disabled for Steam, since it causes issues with some games.
# I also had issues connecting to Epic Games in some online titles.
rm /usr/local/bin/steam

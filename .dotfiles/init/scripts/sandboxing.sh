#!/bin/bash

# Setup Apparmor
groupadd -r audit 2>/dev/null || true
gpasswd -a $USER audit

if ! grep -q '^log_group = audit' /etc/audit/auditd.conf; then
    echo 'log_group = audit' >> /etc/audit/auditd.conf
fi

# Enforce rules
firecfg

# Disabled for Steam, since it causes issues with some games.
# I also had issues connecting to Epic Games in some online titles.
rm /usr/local/bin/steam

# Way too slow for normal usage, using own bwrap sandbox
rm /usr/local/bin/firefox

# Delete empty folders created by firecfg
find ~/ -maxdepth 3 -type d -empty -delete 2>/dev/null || true

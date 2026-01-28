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

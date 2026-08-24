#!/bin/bash

# Setup Apparmor
groupadd -r audit 2>/dev/null || true
gpasswd -a "$USER" audit

grep -q '^log_group = audit' /etc/audit/auditd.conf ||
    echo 'log_group = audit' >> /etc/audit/auditd.conf

# Temporarily allow firecfg without a password
SUDOERS="/etc/sudoers.d/firecfg-$USER"
echo "$USER ALL=(root) NOPASSWD: /usr/bin/firecfg" > "$SUDOERS"
chmod 440 "$SUDOERS"

# Setup Firejail
firecfg --clean
firecfg --add-users "$USER"
runuser -u "$USER" -- sudo firecfg
rm -f "$SUDOERS"

# Delete empty folders created by firecfg
find "/home/$USER" -maxdepth 3 -type d -empty -delete 2>/dev/null || true

# Disable problematic Firejail profiles
rm -f /usr/local/bin/steam
rm -f /usr/local/bin/firefox

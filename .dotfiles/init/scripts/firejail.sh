#!/bin/bash

# Fixes issues with firejail
chown root:root /etc/localtime
chmod 644 /etc/localtime

# Enforce rules
firecfg

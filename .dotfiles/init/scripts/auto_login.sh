#!/bin/bash

# Create override directory
OVERRIDE_DIR="/etc/systemd/system/getty@tty1.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"
mkdir -p "$OVERRIDE_DIR"

# Create override configuration
cat > "$OVERRIDE_FILE" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noreset --noclear --autologin $USERNAME - \${TERM}
EOF

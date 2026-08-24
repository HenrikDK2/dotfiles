#!/bin/bash

OVERRIDE_DIR="/etc/systemd/system/getty@tty1.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

# Create override directory
echo "Creating auto_login file..."
mkdir -p "$OVERRIDE_DIR"

# Create override configuration
cat > "$OVERRIDE_FILE" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noreset --noclear --autologin $USERNAME - \${TERM}
EOF

echo "Done"

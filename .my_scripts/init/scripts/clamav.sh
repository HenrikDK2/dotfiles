#!/bin/bash

clamav_logs=("/var/log/clamav/clamd.log" "/var/log/clamav/clamonacc.log" "/var/log/clamav/freshclam.log")

# Create /var/log/clamav if it doesn't exist
if [ ! -d "/var/log/clamav" ]; then
    sudo mkdir -p /var/log/clamav
fi

for log in "${clamav_logs[@]}"; do
    if [ ! -f "$log" ]; then
        sudo touch "$log"
    fi
    
    sudo chown clamav:clamav "$log"  # Set both owner and group to clamav
    sudo chmod 644 "$log"            # -rw-r--r-- (owner: read+write, group/others: read)
done

sudo freshclam
sudo systemctl enable clamav-clamonacc clamav-daemon clear-clamav-logs clamav-freshclam-once.timer

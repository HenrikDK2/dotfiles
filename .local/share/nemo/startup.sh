#!/bin/bash

# Start nemo
nemo &

# Sleep until nemo exits
while pgrep -x "nemo" > /dev/null; do
	sleep 1
done

# Kill related services no longer used
$HOME/.local/share/nemo/kill_services.sh

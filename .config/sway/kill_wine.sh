#!/bin/bash

# Get the current script's PID
current_pid=$$

# Kill .exe processes, excluding this script
pkill -f '\.exe$' --signal SIGTERM --parent "$current_pid"

# Kill explorer.exe processes
pkill -f 'explorer.exe /desktop' --signal SIGTERM --parent "$current_pid"

# Kill wine processes, excluding this script
pkill -f 'wine' --signal SIGTERM --parent "$current_pid"

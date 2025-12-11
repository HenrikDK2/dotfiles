#!/bin/bash

NOTIFY_MESSAGES=()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DISABLE_NOTIFICATIONS=false
BACKGROUND=false

# Create a hash of current issues to track if they've changed
LOG_HASH_FILE="/tmp/audit_script_last_log_hash"
AUDIT_FLAG="/tmp/audit.flag"

while getopts ":qb" opt; do
    case $opt in
        q)
            DISABLE_NOTIFICATIONS=true
            ;;
        b)  # Will run in background, if any issues are detected, then it will run in the foreground
            BACKGROUND=true
            DISABLE_NOTIFICATIONS=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

notify() {
    local title="System Check: Attention Required"
    local message="$1"
    
    if command -v notify-send >/dev/null; then
        notify-send "$title" "$message"    
    fi
}

format_section() {
    local section_title="$1"
    local section_content="$2"
    local issue_found=false

    # Determine if issues exist
    if [[ -n "$section_content" ]] && [[ "$section_content" != "-- No entries --" ]]; then
       title_color=$RED
       issue_found=true

       # Collect notification messages
       case "$section_title" in
           "Failed systemctl services")
               NOTIFY_MESSAGES+=("Service failures: $(echo "$section_content" | wc -l) services")
               ;;
           "Errors in journalctl")
               NOTIFY_MESSAGES+=("System errors logged")
               ;;
           "Pacnew/Pacsave files found")
               NOTIFY_MESSAGES+=("Config updates needed: $(echo "$section_content" | wc -l) files")
               ;;
           "ClamAV scan results")
               NOTIFY_MESSAGES+=("Virus scan detected issues")
               ;;
       esac
    else
        title_color=$GREEN
    fi

    # Original output formatting
    echo -e "${title_color}${section_title}:${NC}"

    if [[ -n "$section_content" ]]; then
        echo "$section_content" | sed 's/^/  /'
    else
        echo "-- No entries --"
    fi
    
    echo
}

filter_journalctl() {
	# These patterns are what I consider non issues, might be race conditions --
	# GameBoost disabling service, or harmless warnings reported as errors
	local patterns=(
	    "gkr-pam: unable to locate daemon control file"
	    "Inconsistent IP pool management \(start not found\)"
	    "amdgpu: Overdrive is enabled"
	    "usb 1-3.3: device descriptor read/64, error -32"
	    "Failed to find module 'nvidia-uvm'"
	    "Failed to write OSC sequence to TTY, ignoring: Resource temporarily unavailable"
	    "Activation request for 'org.freedesktop.nm_dispatcher' failed."
	    "disabled by hub \(EMI\?\), re-enabling"
	    "Failed to start Timed resync"
	    "Failed to write \"max_performance\" to sysfs attribute \"link_power_management_policy\""
	    "nm-openvpn\\[.*\\]: event_wait : Interrupted system call \\(fd=-1,code=4\\)"
	    "Activation request for 'org.bluez' failed."
	    "systemd-journald-audit.socket: Socket service systemd-journald.service already active, refusing."
	    "Failed to start Portal service \\(GTK/GNOME implementation\\)."
	    "Failed to listen on Journal Audit Socket."
	    "Failed to print table: Broken pipe"
	    "Activation request for 'org.freedesktop.impl.portal.desktop.gtk' failed."
	    "AEAD Decrypt error: bad packet ID \\(may be a replay\\)"
	    "gkr-pam: couldn't unlock the login keyring."
	    "terminated abnormally without generating a coredump" # Coredump is disabled, so this is generated when programs are killed
	    
	)
    local pattern=$(IFS='|'; echo "${patterns[*]}")
    journalctl -b -p 3 --no-pager | grep -Ev "$pattern" | tail -n 20
}

filter_systemctl() {
    local patterns=(
        "^session-[0-9]+\\.scope$"
    )
    local pattern=$(IFS='|'; echo "${patterns[*]}")
    systemctl --failed --no-legend --plain 2>/dev/null \
        | awk '{print $1}' \
        | grep -Ev "$pattern"
}

# Function to generate a hash of current issues
generate_issue_hash() {
    {
        systemctl --failed --no-legend --plain 2>/dev/null
        filter_journalctl
        find /etc -type f \( -name "*.pacnew" -o -name "*.pacsave" \) 2>/dev/null
        for log in "/var/log/clamav/clamd.log" "/var/log/clamav/clamonacc.log"; do
            grep -i -E "infected|FOUND" "$log" 2>/dev/null
        done
    } | sha256sum | cut -d' ' -f1
}

#####################
### CREATE OUTPUT ###
#####################

# Generate current issue hash
CURRENT_HASH=$(generate_issue_hash)

# Service failures
failed_services=$(filter_systemctl)
format_section "Failed systemctl services" "$failed_services"

# Errors from journal
error_logs=$(filter_journalctl)
format_section "Errors in journalctl" "$error_logs"

# Pacnew/pacsave files
pacnew_files=$(find /etc -type f \( -name "*.pacnew" -o -name "*.pacsave" \) 2>/dev/null)
format_section "Pacnew/Pacsave files found" "$pacnew_files"

# ClamAV scan issues
clamav_results=""
clamav_logs=("/var/log/clamav/clamd.log" "/var/log/clamav/clamonacc.log")

for log in "${clamav_logs[@]}"; do
    infected_lines=$(grep -i -E "infected|FOUND" "$log" 2>/dev/null)
    
    if [ -n "$infected_lines" ]; then
        if [ -n "$clamav_results" ]; then
            clamav_results+=$'\n\n'
        fi
        clamav_results+="$infected_lines"
    fi
done

format_section "ClamAV scan results" "$clamav_results"

#########################
### UPDATE FLAG FILE ###
#########################

# Always update the flag file with current status (issues or no issues)
# This allows the monitoring script to detect changes
if [ "${#NOTIFY_MESSAGES[@]}" -gt 0 ]; then
    # Write current hash to flag file when issues exist
    echo "$CURRENT_HASH" > "$AUDIT_FLAG"
else
    # Remove flag file when no issues exist
    rm -f "$AUDIT_FLAG"
fi

#########################
### SEND NOTIFICATION ###
#########################

if [ "$DISABLE_NOTIFICATIONS" = false ] && [ "${#NOTIFY_MESSAGES[@]}" -gt 0 ]; then
    combined_message="System issues detected:"

    for msg in "${NOTIFY_MESSAGES[@]}"; do
        combined_message+="\n- $msg"
    done

    notify "$combined_message"
fi

#########################
### RUN IN FOREGROUND ###
#########################

# If issues are detected and they're new since last time, run in foreground
if [ "$BACKGROUND" = true ] && [ "${#NOTIFY_MESSAGES[@]}" -gt 0 ]; then
    # Check if we have a previous hash
    if [ -f "$LOG_HASH_FILE" ]; then
        PREVIOUS_HASH=$(cat "$LOG_HASH_FILE")
    else
        PREVIOUS_HASH=""
    fi
    
    # Only spawn terminal if the issues are new or changed
    if [ "$CURRENT_HASH" != "$PREVIOUS_HASH" ]; then
        # Save the current hash to track that the user has been notified
        echo "$CURRENT_HASH" > "$LOG_HASH_FILE"
        alacritty -e bash -i -c "$HOME/.dotfiles/scripts/audit.sh; exec bash" &
    fi
fi

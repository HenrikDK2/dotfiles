#!/bin/bash

# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to format output sections
format_section() {
    section_title="$1"
    section_content="$2"

    # Determine title color based on section content
    if [[ -n "$section_content" ]]; then
        title_color=$RED
    else
        title_color=$GREEN
    fi

    echo -e "${title_color}${section_title}:${NC}"
    if [[ -n "$section_content" ]]; then
        echo "$section_content" | sed 's/^/  /'
    else
        echo "  No results found."
    fi
    echo
}

# 1. Check systemctl services for failures
failed_services=$(systemctl --failed --no-legend --plain | awk '{print $1}')
format_section "Failed systemctl services" "$failed_services"

# 2. Check journalctl for important errors
error_logs=$(journalctl -p 3 -b)
format_section "Errors in journalctl (It might be relevant)" "$error_logs"

# 3. Look for pacnew/pacsave files
pacnew_files=$(find /etc -name "*.pacnew" -o -name "*.pacsave" 2>/dev/null)
format_section "Pacnew/Pacsave files found" "$pacnew_files"

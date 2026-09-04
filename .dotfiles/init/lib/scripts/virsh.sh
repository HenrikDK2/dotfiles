#!/bin/bash

# Colors
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

if [[ $EUID -ne 0 ]]; then
    echo "This script needs to be run as root. Re-running with sudo..."
    exec sudo "$0" "$@"
fi

# Clear the screen if clear_screen is available.
if declare -F clear_screen >/dev/null 2>&1; then
    clear_screen
elif command -v clear >/dev/null 2>&1; then
    clear
fi

SCRIPT_PATH="$(realpath "$0")"

if virt-host-validate qemu 2>&1 | grep -q "QEMU: Checking for hardware virtualization.*FAIL"; then
    echo
    echo -e "${YELLOW}WARNING: Hardware virtualization is NOT enabled.${NC}"
    echo
    echo "Please enable virtualization (Intel VT-x/VMX or AMD-V/SVM)"
    echo "in your BIOS/UEFI settings."
    echo
    echo "After enabling virtualization, you must run this script again:"
    echo
    echo -e "  ${GREEN}$SCRIPT_PATH${NC}"
    echo

    read -rp "Press Enter to confirm..."
elif ! virsh net-autostart default; then
    echo
    echo -e "${YELLOW}WARNING: Failed to configure virsh network autostart.${NC}"
    echo
    sleep 3
fi

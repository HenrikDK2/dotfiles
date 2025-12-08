#!/bin/bash

# Configuration
rofi_theme="$HOME/.config/rofi/styles/theme.rasi"
tmp_file="$HOME/.cache/network_menu.tmp"

# Cleanup temporary file on exit
trap '[[ -f "$tmp_file" ]] && rm -f "$tmp_file"' EXIT

# -----------------------------
# Rofi helper
# -----------------------------
rofi_call() {
    local input="$1" theme="${2:-$rofi_theme}" prompt="$3"
    echo -e "$input" | rofi -dmenu -theme "$theme" -p "$prompt" | tr -d '\n'
}

# -----------------------------
# Network functions
# -----------------------------
get_connected_service() {
    local line=$(connmanctl services | grep -E '^\*' | head -n1)
    [[ -z "$line" ]] && echo "Not connected" && return

    local service=$(echo "$line" | awk '{print $NF}')
    local state=$(connmanctl services "$service" | grep "State")

    if echo "$state" | grep -iq "online\|ready"; then
        echo "$service"
    else
        echo "Not connected"
    fi
}

get_all_networks() {
    connmanctl services | grep -E 'wifi_|ethernet_' | awk '{$1=$1};1'
}

get_signal_icon() {
    local strength=$1
    if ((strength >= 75)); then
        echo "📶📶📶"
    elif ((strength >= 50)); then
        echo "📶📶"
    elif ((strength >= 25)); then
        echo "📶"
    else
        echo "📡"
    fi
}

disconnect_network() {
    local service_id="$1"
    connmanctl disconnect "$service_id"
    notify-send "Disconnected from $service_id"
}

connect_network() {
    local service_id="$1" current_connection=$(get_connected_service | awk '{print $NF}')
    [[ -n "$current_connection" && "$current_connection" != "Not connected" && "$current_connection" != "$service_id" ]] && connmanctl disconnect "$current_connection"
    connmanctl connect "$service_id"
    notify-send "Connected to $service_id"
}

get_connection_details() {
    local service_id="$1" raw=$(connmanctl services "$service_id" 2>/dev/null)
    {
        echo "⚠ NOTICE: Editing this file will NOT change any network settings."
        echo "Press Ctrl+Q to return"
        echo "────────────────────────────────────────────────────────────────────────────"
        echo ""
        echo "$raw"
    } > "$tmp_file"
    alacritty -e micro "$tmp_file"
}

enable_autoconnect() { connmanctl config "$1" --autoconnect on; }
disable_autoconnect() { connmanctl config "$1" --autoconnect off; }

# -----------------------------
# Bluetooth functions
# -----------------------------
get_bluetooth_status() {
    local state=$(connmanctl technologies | grep -A5 'technology/bluetooth' | awk -F ' = ' '/Powered/ { print tolower($2) }')
    echo "$state"
}

toggle_bluetooth() {
    local status=$(get_bluetooth_status)
    if [[ "$status" == "true" ]]; then
        connmanctl disable bluetooth
    else
        connmanctl enable bluetooth
    fi
}

# -----------------------------
# ZeroTier functions
# -----------------------------
get_zerotier_status() {
    if ! command -v zerotier-one &>/dev/null; then
        echo "not_installed"
        return
    fi
    systemctl is-active --quiet zerotier-one.service && echo "active" || echo "inactive"
}

toggle_zerotier() {
    local status=$(get_zerotier_status)
    local pia_state=$(piactl get connectionstate)

    if [[ "$status" == "active" ]]; then
		[[ "$pia_state" == "Disconnected" ]] && piactl connect
        systemctl stop zerotier-one.service
    elif [[ "$status" == "inactive" ]]; then
   		[[ "$pia_state" == "Connected" ]] && piactl disconnect

   		# Wait for internet access
   		while ! ping -c 1 -W 2 1.1.1.1 &>/dev/null; do
   		    sleep 0.5
   		done
   		
        systemctl start zerotier-one.service
    fi
}

show_zerotier_details() {
    pkexec bash -c "
tmp_file='$tmp_file'
{
    echo '⚠ NOTICE: Editing this file will NOT affect ZeroTier.'
    echo 'Press Ctrl+Q to close.'
    echo '──────────────────────────────────────────────────────────'
    echo '🔹 ZeroTier Info'
    echo '────────────────'
    zerotier-cli info 2>/dev/null || echo 'No info available.'
    echo ''
    echo '🔹 Networks'
    echo '────────────────'
    zerotier-cli listnetworks 2>/dev/null || echo 'No networks found.'
    echo ''
    echo '🔹 Peers'
    echo '────────────────'
    peers=\$(zerotier-cli listpeers 2>/dev/null)
    [[ -z \"\$peers\" ]] && echo 'No peers found or service not running.' || echo \"\$peers\"
} > \"$tmp_file\""
    alacritty -e micro "$tmp_file"
}

# -----------------------------
# Menus
# -----------------------------
zerotier_menu() {
    local direct_launch=${1:-false}  # true if called with argument

    while true; do
        local status=$(get_zerotier_status)
        local toggle_option=$([[ "$status" == "active" ]] && echo "🔌 Disable" || echo "🔌 Enable")

        # Build menu
        local menu="$toggle_option"
        [[ "$status" == "active" ]] && menu+="\n🔍 Details"

        if [[ "$direct_launch" == true ]]; then
            menu+="\n❌ Exit"
        else
            menu="↩  Back\n$menu"
        fi

        local choice=$(rofi_call "$menu" "$rofi_theme" "ZeroTier:")

        case "$choice" in
            "↩  Back") return ;;
            "❌ Exit") exit 0 ;;
            "🔌 Enable"|"🔌 Disable") toggle_zerotier ;;
            "🔍 Details") show_zerotier_details ;;
            "") exit 0 ;;
        esac
    done
}

networks_menu() {
    local networks_list=$(get_all_networks) current_id=$(get_connected_service | awk '{print $NF}') menu_array=("↩  Back") selected

    while read -r line; do
        [[ -z "$line" ]] && continue
        local id icon suffix
        id=$(echo "$line" | awk '{print $NF}')
        icon=""
        [[ "$id" == *"ethernet_"* ]] && icon=""
        if [[ "$id" == *"wifi_"* ]]; then
            local strength=$(connmanctl services "$id" | awk '/Strength/ {print $NF}')
            icon=$(get_signal_icon "$strength")
        fi
        [[ "$id" == "$current_id" ]] && suffix=" (Connected)" || suffix=""
        menu_array+=("$icon  $id$suffix")
    done <<< "$networks_list"

    local menu_entries=$(printf "%s\n" "${menu_array[@]}")
    selected=$(rofi_call "$menu_entries" "$rofi_theme" "Select Network:")
    [[ "$selected" == "↩  Back" ]] && return
    [[ -z "$selected" ]] && exit 0
    local selected_id=$(echo "$selected" | awk '{print $2}')
    manage_network_connection "$selected_id" "networks"
}

manage_network_connection() {
    local service_id="$1" previous_menu="$2"
    local current_connection=$(get_connected_service | awk '{print $NF}')
    local autoconnect_raw=$(connmanctl services "$service_id" 2>/dev/null | grep "AutoConnect")
    local autoconnect_menu_option menu choice

    if echo "$autoconnect_raw" | grep -iq "true"; then
        autoconnect_menu_option="🔁 Disable Auto Connect"
    else
        autoconnect_menu_option="🔁 Enable Auto Connect"
    fi

    if [[ "$service_id" == "$current_connection" ]]; then
        menu=$(echo -e "↩  Back\n❌ Disconnect\n$autoconnect_menu_option\n🔎 Details")
    else
        menu=$(echo -e "↩  Back\n🔌 Connect\n$autoconnect_menu_option\n🔎 Details")
    fi

    choice=$(rofi_call "$menu" "$rofi_theme" "Manage $service_id")
    case "$choice" in
        "❌ Disconnect") disconnect_network "$service_id" ;;
        "🔌 Connect") connect_network "$service_id" ;;
        "🔁 Enable Auto Connect") enable_autoconnect "$service_id"; manage_network_connection "$service_id" "$previous_menu" ;;
        "🔁 Disable Auto Connect") disable_autoconnect "$service_id"; manage_network_connection "$service_id" "$previous_menu" ;;
        "🔎 Details") get_connection_details "$service_id"; manage_network_connection "$service_id" "$previous_menu" ;;
        "↩  Back") [[ "$previous_menu" == "networks" ]] && networks_menu || main_menu ;;
        "") exit 0 ;;
    esac
}

main_menu() {
    while true; do
        local connected_line=$(get_connected_service)
        local bluetooth_state=$(systemctl is-active bluetooth.service &>/dev/null && get_bluetooth_status || echo "")
        local zerotier_status=$(get_zerotier_status)
        local options="" connection_item="" bluetooth_item="" zerotier_item="" networks_item="  Networks" chosen current_ssid service_id

        # Current network
        if [ "$connected_line" != "Not connected" ]; then
            current_ssid=$(echo "$connected_line" | sed -E 's/\*?[AOR]* *//;s/ wifi_.*//;s/ ethernet_.*//')
            [[ "$connected_line" == *"ethernet_"* ]] && connection_item="  $current_ssid (Connected)"
            [[ "$connected_line" == *"wifi_"* ]] && connection_item="  $current_ssid (Connected)"
            options+="$connection_item\n"
        fi

        # Other menu items
        options+="$networks_item\n"
        [[ -n "$bluetooth_state" ]] && bluetooth_item="  Bluetooth: $([[ "$bluetooth_state" == "true" ]] && echo Disconnect || echo Connect)" && options+="$bluetooth_item\n"
        [[ "$zerotier_status" != "not_installed" ]] && zerotier_item="  ZeroTier" && options+="$zerotier_item\n"
        options+="❌ Exit"

        # Show menu
        chosen=$(rofi_call "$options" "$rofi_theme" "Network Menu:")
        [[ -z "$chosen" ]] && exit 0

        case "$chosen" in
            "$connection_item") service_id=$(echo "$connected_line" | awk '{print $NF}'); manage_network_connection "$service_id" "main" ;;
            "$bluetooth_item") toggle_bluetooth ;;
            "$zerotier_item") zerotier_menu ;;
            "$networks_item") networks_menu ;;
            "❌ Exit") exit 0 ;;
        esac
    done
}

if [[ "$1" == "zerotier" ]]; then
    zerotier_menu true
else
    main_menu
fi

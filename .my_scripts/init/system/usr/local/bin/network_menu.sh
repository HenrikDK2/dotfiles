#!/bin/bash

rofi_theme="$HOME/.config/rofi/styles/theme.rasi"
network_output_theme="$HOME/.config/rofi/styles/network_output.rasi"

log() {
    local func="$1"
    shift
    if [[ -z "${LOGGED_FUNCS[$func]}" ]]; then
        echo -e "\n-------------------------------------------------------------------" >&2
        LOGGED_FUNCS["$func"]=1
    fi
    echo "[${func}] $*" >&2
}

rofi_call() {
    local input="$1"
    local theme="${2:-$rofi_theme}"
    local prompt="$3"
    echo -e "$input" | rofi -dmenu -theme "$theme" -p "$prompt" | tr -d '\n'
}

get_connected_service() {
    log get_connected_service "Checking current connection..."
    active_service_line=$(connmanctl services | grep -E '^\*' | head -n 1)
    log get_connected_service "Active service line: $active_service_line"

    if [ -z "$active_service_line" ]; then
        echo "Not connected"
    else
        active_service=$(echo "$active_service_line" | awk '{print $NF}')
        log get_connected_service "Active service ID: $active_service"
        service_state=$(connmanctl services "$active_service" | grep "State")
        if echo "$service_state" | grep -iq "online\|ready"; then
            echo "$active_service"
        else
            echo "Not connected"
        fi
    fi
}

get_all_networks() {
    log get_all_networks "Fetching all available networks..."
    networks=$(connmanctl services | grep -E 'wifi_|ethernet_' | awk '{$1=$1};1')
    log get_all_networks "Networks: $networks"
    echo "$networks"
}

get_signal_icon() {
    local strength=$1
    if (( strength >= 75 )); then
        echo "📶📶📶"
    elif (( strength >= 50 )); then
        echo "📶📶"
    elif (( strength >= 25 )); then
        echo "📶"
    else
        echo "📡"
    fi
}

get_bluetooth_status() {
    log get_bluetooth_status "Checking Bluetooth status..."
    state=$(connmanctl technologies | grep -A 5 'technology/bluetooth' | awk -F ' = ' '/Powered/ { print tolower($2) }')
    log get_bluetooth_status "Bluetooth powered: $state"
    echo "$state"
}

toggle_bluetooth() {
    local current_status
    current_status=$(get_bluetooth_status)
    log toggle_bluetooth "Current status: $current_status"

    if [[ "$current_status" == "true" ]]; then
        connmanctl disable bluetooth
        log toggle_bluetooth "Bluetooth disabled"
    else
        connmanctl enable bluetooth
        log toggle_bluetooth "Bluetooth enabled"
    fi
}

# -------------------------------
# 🔹 ZeroTier Integration
# -------------------------------

get_zerotier_status() {
    log get_zerotier_status "Checking ZeroTier status..."
    if ! command -v zerotier-one &>/dev/null; then
        echo "not_installed"
        return
    fi

    if systemctl is-active --quiet zerotier-one.service 2>/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

toggle_zerotier() {
    local current_status
    current_status=$(get_zerotier_status)

    if [[ "$current_status" == "active" ]]; then
        systemctl stop zerotier-one.service
        notify-send "ZeroTier" "Disconnected"
    elif [[ "$current_status" == "inactive" ]]; then
        systemctl start zerotier-one.service
        notify-send "ZeroTier" "Connected"
    else
        notify-send "ZeroTier" "Not installed"
    fi
}

show_zerotier_details() {
    ensure_privileges || return

    tmp_file="/tmp/zerotier_details.tmp"
    {
        echo "⚠ NOTICE: Editing this file will NOT affect ZeroTier."
        echo "Press Ctrl+Q to close."
        echo "──────────────────────────────────────────────────────────"
        echo ""
        echo "🔹 ZeroTier Info"
        echo "────────────────"
        zerotier-cli info 2>/dev/null || echo "No info available."
        echo ""
        echo "🔹 Networks"
        echo "────────────────"
        zerotier-cli listnetworks 2>/dev/null || echo "No networks found."
        echo ""
        echo "🔹 Peers"
        echo "────────────────"
        peers=$(zerotier-cli listpeers 2>/dev/null)
        [[ -z "$peers" ]] && echo "No peers found or service not running." || echo "$peers"
    } > "$tmp_file"

    alacritty -e micro "$tmp_file"
    rm -f "$tmp_file"
}

zerotier_menu() {
    while true; do
        status=$(get_zerotier_status)

        if [[ "$status" == "not_installed" ]]; then
            notify-send "ZeroTier" "Not installed on this system"
            return
        fi

        if [[ "$status" == "active" ]]; then
            toggle_option="🔌 Disconnect"
        else
            toggle_option="🔌 Connect"
        fi

        menu="↩ Back\n$toggle_option\n🔍 Details"
        choice=$(rofi_call "$menu" "$rofi_theme" "ZeroTier:")

        case "$choice" in
            "↩ Back") return ;;
            "🔌 Connect"|"🔌 Disconnect") toggle_zerotier ;;
            "🔍 Details") show_zerotier_details ;;
            "") exit 0 ;;
        esac
    done
}

# ----------------------------------------------------------
# Remaining network + bluetooth management unchanged
# ----------------------------------------------------------

disconnect_network() {
    local service_id="$1"
    connmanctl disconnect "$service_id"
    notify-send "Disconnected from $service_id"
}

connect_network() {
    local service_id="$1"
    current_connection=$(get_connected_service | awk '{print $NF}' | tr -d '\n')

    if [[ -n "$current_connection" && "$current_connection" != "Not connected" && "$current_connection" != "$service_id" ]]; then
        connmanctl disconnect "$current_connection"
    fi

    connmanctl connect "$service_id"
    notify-send "Connected to $service_id"
}

get_connection_details() {
    local service_id="$1"
    raw_details=$(connmanctl services "$service_id" 2>/dev/null)
    tmp_file="/tmp/connman_details.tmp"

    {
        echo "⚠ NOTICE: Editing this file will NOT change any network settings."
        echo "Press Ctrl+Q to return"
        echo "────────────────────────────────────────────────────────────────────────────"
        echo ""
        echo "$raw_details"
    } > "$tmp_file"

    alacritty -e micro "$tmp_file"
    rm -f "$tmp_file"
}

enable_autoconnect() {
    local service_id="$1"
    connmanctl config "$service_id" --autoconnect on
}

disable_autoconnect() {
    local service_id="$1"
    connmanctl config "$service_id" --autoconnect off
}

manage_network_connection() {
    local service_id="$1"
    local previous_menu="$2"
    current_connection=$(get_connected_service | awk '{print $NF}' | tr -d '\n')

    local autoconnect_menu_option
    local autoconnect_raw=$(connmanctl services "$service_id" 2>/dev/null | grep "AutoConnect")

    if echo "$autoconnect_raw" | grep -iq "true"; then
        autoconnect_menu_option="🔁 Disable Auto Connect"
    else
        autoconnect_menu_option="🔁 Enable Auto Connect"
    fi

    if [[ "$service_id" == "$current_connection" ]]; then
        connection_menu=$(echo -e "↩ Back\n❌ Disconnect\n$autoconnect_menu_option\n🔎 Details")
    else
        connection_menu=$(echo -e "↩ Back\n🔌 Connect\n$autoconnect_menu_option\n🔎 Details")
    fi

    choice=$(rofi_call "$connection_menu" "$rofi_theme" "Manage $service_id")

    case "$choice" in
        "❌ Disconnect") disconnect_network "$service_id" ;;
        "🔌 Connect") connect_network "$service_id" ;;
        "🔁 Enable Auto Connect") enable_autoconnect "$service_id"; manage_network_connection "$service_id" "$previous_menu" ;;
        "🔁 Disable Auto Connect") disable_autoconnect "$service_id"; manage_network_connection "$service_id" "$previous_menu" ;;
        "🔎 Details") get_connection_details "$service_id"; manage_network_connection "$service_id" "$previous_menu" ;;
        "↩ Back") [[ "$previous_menu" == "networks" ]] && networks_menu || main_menu ;;
        "") exit 0 ;;
    esac
}

networks_menu() {
    networks_list=$(get_all_networks)
    current_id=$(get_connected_service | awk '{print $NF}')
    menu_entries="↩ Back\n"

    while read -r line; do
        ssid=$(echo "$line" | sed -E 's/\*?[AOR]* *//;s/ wifi_.*//')
        id=$(echo "$line" | awk '{print $NF}')
        [[ -z "$ssid" || -z "$id" || "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$id" == *"ethernet_"* ]]; then
            icon=""
            suffix=""
            [[ "$id" == "$current_id" ]] && suffix=" (Connected)"
            menu_entries+="$icon $id$suffix\n"
        elif [[ "$id" == *"wifi_"* ]]; then
            signal_strength=$(connmanctl services "$id" | grep Strength | awk '{print $NF}')
            signal_icon=$(get_signal_icon "$signal_strength")
            suffix=""
            [[ "$id" == "$current_id" ]] && suffix=" (Connected)"
            menu_entries+="$signal_icon $id$suffix\n"
        fi
    done <<< "$networks_list"

    selected=$(rofi_call "$menu_entries" "$rofi_theme" "Select Network:")

    case "$selected" in
        "↩ Back") return ;;
        "") exit 0 ;;
        *) selected_id=$(echo "$selected" | awk '{print $2}'); manage_network_connection "$selected_id" "networks" ;;
    esac
}

main_menu() {
    while true; do
        connected_line=$(get_connected_service)
        [[ $(systemctl is-active bluetooth.service) == "active" ]] && bluetooth_state=$(get_bluetooth_status) || bluetooth_state=""
        zerotier_status=$(get_zerotier_status)

        options=""

        if [ "$connected_line" != "Not connected" ]; then
            current_ssid=$(echo "$connected_line" | sed -E 's/\*?[AOR]* *//;s/ wifi_.*//;s/ ethernet_.*//')
            if [[ "$connected_line" == *"ethernet_"* ]]; then
                connection_item="  $current_ssid (Connected)"
            elif [[ "$connected_line" == *"wifi_"* ]]; then
                connection_item="  $current_ssid (Connected)"
            fi
            options+="$connection_item\n"
        fi

        if [[ "$bluetooth_state" != "" ]]; then
            if [[ "$bluetooth_state" == "true" ]]; then
                bluetooth_item=" Bluetooth: Disconnect"
            else
                bluetooth_item=" Bluetooth: Connect"
            fi
            options+="$bluetooth_item\n"
        fi

        if [[ "$zerotier_status" != "not_installed" ]]; then
            zerotier_item=" ZeroTier"
            options+="$zerotier_item\n"
        fi

        networks_item=" Networks"
        options+="$networks_item\n❌ Exit"

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

main_menu

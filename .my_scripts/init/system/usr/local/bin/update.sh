#!/bin/bash
set -euo pipefail -o noclobber
IFS=$'\n\t'

temp_user=""

# Cleanup function for user and sudoers
cleanup() {
    if [[ -n "$temp_user" ]]; then
        pkill -u "$temp_user" 2>/dev/null || true
        userdel -rf "$temp_user" >/dev/null 2>&1 || true
        rm -f "/etc/sudoers.d/$temp_user" >/dev/null 2>&1
    fi
}

# Network check function with max attempts
wait_for_network() {
    local max_attempts=10
    local attempt=0

    echo "Checking network connection (max $max_attempts attempts)..."

    while (( attempt++ < max_attempts )); do
        if ping -c 1 -W 3 8.8.8.8 &>/dev/null || \
           ping -c 1 -W 3 1.1.1.1 &>/dev/null || \
           curl -fs --connect-timeout 3 http://captive.apple.com &>/dev/null; then
            echo "Network connection established"
            return 0
        fi

        echo "Attempt $attempt/$max_attempts - Waiting for network..."
        sleep 30
    done

    echo "❌ Error: Network connection failed after $max_attempts attempts" >&2
    return 1
}

# Configure secure temporary user
setup_user() {
    # Generate a unique username safely
    until temp_user=$(openssl rand -hex 6) && ! id "$temp_user" &>/dev/null; do :; done

    # Create system user with no password and locked account
    useradd -r -m -d "/var/lib/$temp_user" -s /bin/bash "$temp_user"
    passwd -l "$temp_user" &>/dev/null

    # Secure home directory
    chmod 700 "/var/lib/$temp_user"

    # Limit sudo privileges strictly to needed commands
    cat <<EOF > "/etc/sudoers.d/$temp_user"
$temp_user ALL=(ALL) NOPASSWD: /usr/bin/pacman, /usr/bin/yay
EOF
    chmod 440 "/etc/sudoers.d/$temp_user"
    chown root:root "/etc/sudoers.d/$temp_user"
}

update_system() {
    echo "Updating system packages..."
    sudo -iu "$temp_user" \
        yay -Syu --noconfirm \
        --useask \
        --ask 4 \
        --cleanmenu=0 \
        --diffmenu=0 \
        --editmenu=0 \
        --answerclean None \
        --answerdiff None \
        --answeredit None \
        --answerupgrade All \
        --overwrite="*" \
        --noredownload 
}

# Wait for network before proceeding
wait_for_network || exit 1

# Ensure cleanup on exit
trap cleanup EXIT

# Flatpak updates
if command -v flatpak &>/dev/null; then
    echo "Updating Flatpaks..."
    flatpak update --noninteractive --assumeyes
fi

# System packages updates
if command -v yay &>/dev/null; then
    setup_user

    # First attempt
    if ! update_system; then
        echo -e "\nTrying to resolve issue by refreshing mirrorlist\n"
        /usr/local/bin/mirrors.sh

        # Second attempt
        echo -e "\n\033[1mRetrying updates...\033[0m\n"
        if ! update_system; then
            echo "❌ Update failed after retry" >&2
            exit 1
        fi
    fi
fi

echo "✅ Update process finished."
exit 0

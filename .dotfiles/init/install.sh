#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# All variables listed in here (packages, user, localization and more...)
source $SCRIPT_DIR/env.sh

# $1 - offset from top (default: 0)
function clear_screen() {
    local lines=$(tput lines)
    local offset=${1:-0}
    local clear_lines=$((lines - offset))

    if (( clear_lines < 0 )); then
        clear_lines=0
    fi

    # Push old content off
    for ((i=0; i<clear_lines; i++)); do
        echo ""
    done

    # Move prompt up by printing blank lines after clearing
    tput cup "$offset" 0
}

# Script requires root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Script requires internet connection
if ! ping -c 1 "8.8.8.8" >/dev/null 2>&1; then
    echo "No internet connection."
    exit 1
fi

# Set password for root if none exist
if ! passwd -S root 2>/dev/null | grep -q "P"; then
	clear_screen
    printf "Please set a ${RED}root${RESET} password:\n\n"
    passwd root
fi

# Check if user exists, if not, then create user
if ! id "$USERNAME" &>/dev/null; then
    echo "Creating user '$USERNAME'..."
    useradd -m -G wheel $USERNAME
	
	clear_screen
    printf "Please set a ${GREEN}$USERNAME${RESET} password:\n\n"
    passwd $USERNAME
fi

# Check if .dotfiles is inside home directory, if not, then initialize git repo
if ! [ -d "$HOME/.dotfiles" ]; then
    # Removes git warnings
    git config --global init.defaultBranch main
    git config --global --add safe.directory $HOME

	# Initialize repo in home directory
	rm -rf "$HOME/.git"
    (cd $HOME && git init && git remote add origin $GITHUB_REPO && git fetch && git reset origin/master --hard)
    sudo chown -R $USERNAME:$USERNAME $HOME && chmod 700 $HOME
    (cd $HOME && git remote set-url origin $GITHUB_REPO_SSH)

	# Replace current set envs on new dotfiles
    cp -f "$SCRIPT_DIR/env.sh" "$HOME/.dotfiles/init/env.sh"
fi

# Enable multilib, DisableDownloadTimeout, and ParallelDownloads
if ! grep -q "DisableDownloadTimeout" "/etc/pacman.conf"; then
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
	sed -i "/ParallelDownloads/c\ParallelDownloads = 10\nDisableDownloadTimeout" /etc/pacman.conf
	pacman -Suuy
fi

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set localization
for locale in "${LOCALES[@]}"; do
    sed -i "s/^#$locale/$locale/" /etc/locale.gen
done
echo "LANG=$LANG" | tee /etc/locale.conf
echo "LC_TIME=$LC_TIME" | tee -a /etc/locale.conf
echo "KEYMAP=$KEYMAP" | tee /etc/vconsole.conf
locale-gen

# Set hostname
echo "$HOSTNAME" | tee /etc/hostname

# Enable network time sync
timedatectl set-ntp true

# Copy system configs & install system packages
cp -rf $SCRIPT_DIR/system/* /
chmod -R 755 /usr/local/bin
chown -R root:root /usr/local/bin

# Install system pkgs
pacman -Syu ${PACKAGES[@]} --ask 4 --needed
/usr/local/bin/local_pkgs/main.sh

# Enable essential system services
systemctl enable "${SYSTEM_SERVICES_TO_ENABLE[@]}"

# Mask unwanted services
systemctl mask "${SYSTEM_SERVICES_TO_MASK[@]}"

# Set default shell to fish
usermod -s /usr/bin/fish $USERNAME
usermod -s /usr/bin/fish root

# User system services
mkdir -p "$USER_SYSTEMD_DIR/default.target.wants"
ln -sf /usr/lib/systemd/user/wireplumber.service "$USER_SYSTEMD_DIR/default.target.wants/"
ln -sf /usr/lib/systemd/user/psd.service "$USER_SYSTEMD_DIR/default.target.wants/"
ln -sf /dev/null "$USER_SYSTEMD_DIR/at-spi-dbus-bus.service"

source $SCRIPT_DIR/scripts/bootloader.sh
source $SCRIPT_DIR/scripts/auto_login.sh
source $SCRIPT_DIR/scripts/mozilla.sh
source $SCRIPT_DIR/scripts/heroic.sh
source $SCRIPT_DIR/scripts/qbittorrent.sh
source $SCRIPT_DIR/scripts/drive_optimizations.sh
source $SCRIPT_DIR/scripts/auto_update.sh
source $SCRIPT_DIR/scripts/firewall.sh
source $SCRIPT_DIR/scripts/gpu_drivers.sh

# This will regenerate the initial ramdisk environment for all installed kernels
mkinitcpio -P

# Remove initial pacsave/pacnew files
find /etc \( -name "*.pacnew" -o -name "*.pacsave" \) -print0 | xargs -0 rm -f

# Fix permission issues (Exclude .dotfiles)
find $HOME -path "$HOME/.dotfiles" -prune -o -exec chown "$USER:$USER" {} + 2>/dev/null

# Reboot
for i in {5..1}; do echo "Rebooting in $i..."; sleep 1; done; reboot

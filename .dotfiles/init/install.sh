#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source $SCRIPT_DIR/env.sh

function section() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# $1 - offset from top (default: 0)
function clear_screen() {
    local lines=$(tput lines)
    local offset=${1:-0}
    local clear_lines=$((lines - offset))

    if (( clear_lines < 0 )); then
        clear_lines=0
    fi

    for ((i=0; i<clear_lines; i++)); do
        echo ""
    done

    tput cup "$offset" 0
}

if [ "$(id -u)" -ne 0 ]; then
    echo "This script needs to be run as root (su)"
    su -c "$0 $@"
    exit 0
fi

if ! ping -c 1 "8.8.8.8" >/dev/null 2>&1; then
    echo "No internet connection."
    exit 1
fi

if ! passwd -S root 2>/dev/null | grep -q "P"; then
	section "Create root password"
    clear_screen
    printf "Please set a ${RED}root${RESET} password:\n\n"
    passwd root
fi

if ! id "$USERNAME" &>/dev/null; then
	section "Create user"
    echo "Creating user '$USERNAME'..."
    useradd -m -G wheel $USERNAME

    clear_screen
    printf "Please set a ${GREEN}$USERNAME${RESET} password:\n\n"
    passwd $USERNAME
fi

if ! [ -d "$HOME/.dotfiles" ]; then
	section "Initializing dotfiles"

	# Configure git
	git config --global init.defaultBranch main
	git config --global --add safe.directory "$HOME"

	# Initialize repo and fetch dotfiles
	rm -rf "$HOME/.git"
	(
	    cd "$HOME"
	    git init
	    git remote add origin "$GITHUB_REPO"
	    git fetch
	    git reset --hard origin/arch-hyprland
	    git checkout arch-hyprland
	)

	# Fix ownership and permissions
	sudo chown -R "$USERNAME:$USERNAME" "$HOME"
	chmod 700 "$HOME"

	# Switch remote to SSH
	(
	    cd "$HOME"
	    git remote remove origin
	    git remote add origin "$GITHUB_REPO_SSH"
	)

	# Copy environment config and restore ownership
	cp -f "$SCRIPT_DIR/env.sh" "$HOME/.dotfiles/init/env.sh"
	chown -R "$USER:$USER" "$HOME"
fi

if ! grep -q "DisableDownloadTimeout" "/etc/pacman.conf"; then
	section "Configuring pacman"
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
    sed -i "/ParallelDownloads/c\ParallelDownloads = 10\nDisableDownloadTimeout" /etc/pacman.conf
    pacman -Suuy
fi

section "Setting timezone"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "New timezone: $TIMEZONE"

section "Setting localization and hostname"
for locale in "${LOCALES[@]}"; do
    sed -i "s/^#$locale/$locale/" /etc/locale.gen
done
echo "LANG=$LANG" | tee /etc/locale.conf
echo "LC_TIME=$LC_TIME" | tee -a /etc/locale.conf
echo "KEYMAP=$KEYMAP" | tee /etc/vconsole.conf
echo "$HOSTNAME" | tee /etc/hostname
locale-gen

section "Enabling NTP"
timedatectl set-ntp true
echo "Done"

section "Copying system configs"
cp -rf $SCRIPT_DIR/system/* /

section "Installing system packages"
pacman -Syu ${PACKAGES[@]} --ask 4 --needed
/usr/local/bin/local_pkgs/main.sh

section "Enabling required system services"
systemctl enable "${SYSTEM_SERVICES_TO_ENABLE[@]}"
echo "Done"

section "Masking unwanted services"
systemctl mask "${SYSTEM_SERVICES_TO_MASK[@]}"
echo "Done"

section "Setting default shell to fish"
echo "Changing shells for both $USERNAME and root"
usermod -s /usr/bin/fish $USERNAME
usermod -s /usr/bin/fish root
echo "Done"

section "Configuring user systemd services"
mkdir -p "$USER_SYSTEMD_DIR/default.target.wants"
ln -sf /usr/lib/systemd/user/wireplumber.service "$USER_SYSTEMD_DIR/default.target.wants/"
ln -sf /usr/lib/systemd/user/psd.service "$USER_SYSTEMD_DIR/default.target.wants/"
ln -sf /dev/null "$USER_SYSTEMD_DIR/at-spi-dbus-bus.service"
echo "Done"

section "Bootloader"
source $SCRIPT_DIR/scripts/bootloader.sh

section "Auto login"
source $SCRIPT_DIR/scripts/auto_login.sh

section "Mozilla"
source $SCRIPT_DIR/scripts/mozilla.sh

section "Heroic"
source $SCRIPT_DIR/scripts/heroic.sh

section "qBittorrent"
source $SCRIPT_DIR/scripts/qbittorrent.sh

section "Drive optimizations"
source $SCRIPT_DIR/scripts/drive_optimizations.sh

section "Auto update"
source $SCRIPT_DIR/scripts/auto_update.sh

section "Firewall"
source $SCRIPT_DIR/scripts/firewall.sh

section "GPU drivers"
source $SCRIPT_DIR/scripts/gpu_drivers.sh

section "Sandboxing"
source $SCRIPT_DIR/scripts/sandboxing.sh

section "Microsoft fonts"
source $SCRIPT_DIR/scripts/microsoft_fonts.sh

section "Rebuilding initramfs"
mkinitcpio -P

section "Removing pacnew/pacsave files"
find /etc \( -name "*.pacnew" -o -name "*.pacsave" \) -print0 | xargs -0 rm -f
echo "Done."

section "Fixing permissions"
find $HOME -path "$HOME/.dotfiles" -prune -o -exec chown "$USER:$USER" {} + 2>/dev/null || true
echo "Done."

section "Rebooting"
for i in {5..1}; do echo "Rebooting in $i..."; sleep 1; done; reboot

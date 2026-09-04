#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/lib/env.sh
source $SCRIPT_DIR/lib/common.sh

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

    for group in wheel libvirt; do
        getent group "$group" &>/dev/null || groupadd "$group"
    done

    useradd -m -G wheel,libvirt "$USERNAME"

    clear_screen
    printf "Please set a ${GREEN}%s${RESET} password:\n\n" "$USERNAME"
    passwd "$USERNAME"
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

	# Fix ownership
	chown -R "$USER:$USER" "$HOME"
fi

if ! grep -q "DisableDownloadTimeout" "/etc/pacman.conf"; then
	section "Configuring pacman"
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
    sed -i "/ParallelDownloads/c\ParallelDownloads = 10\nDisableDownloadTimeout" /etc/pacman.conf
    pacman -Suuy
fi

section "Setting hostname"
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF
echo "Done"

section "Setting timezone"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
chown -R root:root /usr/share/zoneinfo
hwclock --systohc
echo "New timezone: $TIMEZONE"

section "Setting localization"
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
mkdir -p /tmp/system_files
cp -rf "$SCRIPT_DIR/files/system/"* /tmp/system_files/
chown -R root:root /tmp/system_files
cp -rf /tmp/system_files/* /
echo "Done"

section "Installing system packages"
pacman -Syu ${PACKAGES[@]} --ask 4 --needed
/usr/local/bin/local_pkgs/main.sh

section "Enabling required system services"
systemctl enable "${SYSTEM_SERVICES_TO_ENABLE[@]}"
echo "Done"

section "Masking unwanted system services"
systemctl mask "${SYSTEM_SERVICES_TO_MASK[@]}"
echo "Done"

section "Configuring user systemd services"
for unit in "${USER_SERVICES_TO_ENABLE[@]}"; do
    case "$unit" in
        *.socket)  target=sockets.target ;;
        *.service) target=default.target ;;
        *) echo "Warning: unsupported user unit type: $unit" >&2; continue ;;
    esac

    src="/usr/lib/systemd/user/$unit"
    dst="$USER_SYSTEMD_DIR/$target.wants/$unit"

    [[ -e "$src" ]] || continue
    mkdir -p "${dst%/*}"

    [[ -e "$dst" || -L "$dst" ]] || ln -sv "$src" "$dst"
done
echo "Done"

section "Setting default shell to fish"
echo "Changing shells for both $USERNAME and root"
usermod -s /usr/bin/fish $USERNAME
usermod -s /usr/bin/fish root
echo "Done"

section "Configuring virsh to autostart"
source $SCRIPT_DIR/lib/scripts/virsh.sh

section "Bootloader"
source $SCRIPT_DIR/lib/scripts/bootloader.sh

section "Auto login"
source $SCRIPT_DIR/lib/scripts/auto_login.sh

section "Mozilla"
source $SCRIPT_DIR/lib/scripts/mozilla.sh

section "Heroic"
source $SCRIPT_DIR/lib/scripts/heroic.sh

section "Tidal-hifi"
source $SCRIPT_DIR/lib/scripts/tidal-hifi.sh

section "qBittorrent"
source $SCRIPT_DIR/lib/scripts/qbittorrent.sh

section "Drive optimizations"
source $SCRIPT_DIR/lib/scripts/drive_optimizations.sh

section "Auto update"
source $SCRIPT_DIR/lib/scripts/auto_update.sh

section "Firewall"
source $SCRIPT_DIR/lib/scripts/firewall.sh

section "GPU drivers"
source $SCRIPT_DIR/lib/scripts/gpu_drivers.sh

section "Microsoft fonts"
source $SCRIPT_DIR/lib/scripts/microsoft_fonts.sh

section "Sandboxing"
source $SCRIPT_DIR/lib/scripts/sandboxing.sh

section "Removing pacnew/pacsave files"
find /etc \( -name "*.pacnew" -o -name "*.pacsave" \) -print0 | xargs -0 rm -f
echo "Done."

section "Fixing permissions"
chmod 440 /etc/sudoers.d/config
echo "Done."

section "Rebooting"
for i in {5..1}; do echo "Rebooting in $i..."; sleep 1; done; reboot

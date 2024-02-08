#!/bin/bash

source $HOME/.my_scripts/init/scripts/functions.sh

# Check if sudo and git are installed
if [ ! command -v sudo &> /dev/null || ! command -v git &> /dev/null ]; then
    echo "Sudo and/or Git is not installed"
    exit 1
fi

# Check if user has root permissions
if [[ $EUID -eq 0 ]]; then
   echo "You shouldn't run this script as root" 
   exit 1
fi

# Check for an internet connection
if ! ping -c 1 google.com >/dev/null 2>&1; then
  echo "An internet connection is required to run this script."
  exit 1
fi

# Copy system files
sudo cp -r ~/.my_scripts/init/system/* /

# Avoid stalls on memory allocations
total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
min_free_kbytes=$((total_memory * 2 / 100)) # 2% of memory
sudo sed -i "s/#MEM/$min_free_kbytes/" /etc/tmpfiles.d/performance.conf

# Config settings for Heroic Games Launcher
if [ ! -d "$HOME/.config/heroic" ]; then
	cp -r $HOME/.my_scripts/init/heroic $HOME/.config
	sed -i "s/#NAME/$USER/" $HOME/.config/heroic/config.json
fi

# Improve ext4 performance
$HOME/.my_scripts/init/scripts/ext4_optimizations.sh

# Enable multilib, DisableDownloadTimeout, and ParallelDownloads
if ! grep -q "DisableDownloadTimeout" "/etc/pacman.conf"; then
	sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
	sudo sed -i "/ParallelDownloads/c\ParallelDownloads = 10\nDisableDownloadTimeout" /etc/pacman.conf
	sudo pacman -Suuy
fi

# Install required packages for building/scripts
sudo pacman -S base-devel bc curl wget --noconfirm --needed

# Makepkg related packages (Flags in ~/.makepkg.conf)
sudo pacman -S mold zstd pigz pbzip2 xz --noconfirm --needed

# Install yay
if [ -z "$(pacman -Qe | grep yay)" ]; then
	git clone https://aur.archlinux.org/yay.git
	sudo chmod 777 -R ./yay
	(cd yay && makepkg -si --noconfirm)
	rm -rf ./yay
fi

# Reflector - Get latest mirrors
if [ -z "$(pacman -Qe | grep reflector)" ]; then
	sudo pacman -S reflector --noconfirm --needed
	sudo reflector --verbose --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
	sudo systemctl enable reflector.timer # Update mirrorlist weekly
fi

# Install CachyOS repo
$HOME/.my_scripts/init/scripts/cachyos-repo.sh

# Add bootloader entries, and install kernel
clear
printf "Only for systemd-boot! - Add bootloader entries?\n\n"
printf "This includes kernel hardening, hibernation, ucode, tweaks and unlock access to AMD overclocking"

if confirm; then
	source $HOME/.my_scripts/init/scripts/bootloader.sh
fi

# Ultrawide gaps on workspace 1
clear
printf "Only for 5120x1440 ultrawide monitor!\n\n"
printf "Do you want to have a 1440p window in the center of workspace 1?"

if confirm; then 
    mkdir ~/.config/sway/config.d
    cp ~/.my_scripts/init/config.d/workspace-gaps ~/.config/sway/config.d/workspace-gaps
else
    rm -rf ~/.config/sway/config.d/workspace-gaps
fi

# Optimized Firefox/Thunderbird profile
clear
printf "Do you wish to use an optimized Firefox/Thunderbird profile?\n\n"
printf "It disables telemetry, animations and more for privacy and performance.\n\n"
printf "This will reset your current profile, do you want to proceed?"

if confirm; then 
    rm -rf ~/.mozilla ~/.thunderbird;
    cp -r ~/.my_scripts/init/.thunderbird ~/.thunderbird;
    cp -r ~/.my_scripts/init/.mozilla ~/.mozilla;
    cp -r ~/.mozilla/firefox/vem3poti.dev-edition-default ~/.mozilla/firefox/vem3poti.default-release; 
	cp -r ~/.mozilla/firefox/vem3poti.dev-edition-default ~/.mozilla/firefox/vem3poti.default-nightly; 
fi

# Install Virt-manager
clear
printf "This is for virtual machines.\n\n"
printf "Do you want to install virt-manager?"

if confirm; then
    yay -S virt-manager qemu-desktop libvirt edk2-ovmf iptables-nft dmidecode --needed;
	sudo systemctl enable --now libvirtd virtlogd;
	sudo usermod -a -G libvirt $(whoami);
fi

# Setup bluetooth
clear
printf "This is for bluetooth.\n\n"
printf "Do you want to install blueman?"

if confirm; then
    sudo pacman -S blueman --needed --noconfirm;
    sudo systemctl enable --now bluetooth.service;
fi

# GPU drivers
clear
if [[ $(get_primary_gpu) == "nvidia" ]]; then
	echo "Nvidia GPU drivers not yet implemented..."
	read -p "Press enter to continue"
elif [[ $(get_primary_gpu) == "amd" ]]; then
	sudo pacman -S mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils --noconfirm
	sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf
	sudo mkinitcpio -P;
elif [[ $(get_primary_gpu) == "intel" ]]; then
	sudo pacman -S mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver --noconfirm
fi

# Packages
yay -S heroic-games-launcher-bin proton-ge-custom-bin ttf-ms-fonts all-repository-fonts cmst swaylock-effects-git --needed --noconfirm
sudo pacman -S adobe-source-sans-fonts ttf-jetbrains-mono adobe-source-serif-fonts cantarell-fonts otf-font-awesome pipewire pipewire-audio pipewire-pulse pipewire-alsa pipewire-jack wireplumber mangohud lib32-mangohud btop cabextract fuse cups dconf dbus-broker deluge deluge-gtk dnsmasq firefox fish fisher gamemode gamescope glib2 gnome-keyring grim gvfs gvfs-mtp imv steam discord alacritty lib32-gamemode lib32-libvdpau lib32-pipewire-jack libappindicator-gtk2 libappindicator-gtk3 libsecret mako man-db micro mpv nemo nemo-fileroller nemo-preview npm ntfs-3g openvr p7zip pavucontrol pciutils polkit polkit-gnome qt5-declarative qt5-wayland qt6-declarative qt6-wayland scrot seahorse slurp swappy sway swaybg tesseract-data-eng thunderbird ufw unrar unzip code wayland-protocols wl-clipboard waybar wine wofi xdg-desktop-portal xdg-desktop-portal-wlr xorg-xwayland --needed

# Make user part of the games group (Allows proton to set niceness of process)
sudo usermod -a -G games $(whoami)

# Change default, and current user shell to fish
sudo chsh -s /bin/fish && sudo chsh -s /bin/fish $(whoami)

# Enable UFW and add firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo sed -i 's/-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT/-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/' /etc/ufw/before.rules
echo "Port 1065" | sudo tee /etc/ssh/sshd_config.d/99-port.conf
sudo ufw limit 1065/tcp #SSH
sudo ufw allow 631/tcp #CUPS (printer)
sudo ufw allow ftp/tcp
sudo ufw allow http/tcp
sudo ufw allow https/tcp
sudo ufw logging off
sudo ufw enable

# Clock sync
sudo timedatectl set-ntp true

# Enable services
sudo systemctl enable ufw cups dnsmasq denyhosts dbus-broker fstrim.timer
systemctl --user enable wireplumber dbus-broker

# Disable services
systemctl --user mask at-spi-dbus-bus
sudo systemctl mask rtkit-daemon ldconfig.service upower systemd-resolved connman-vpn

# Remove initial pacsave/pacnew files
sudo find /etc -name "*.pacnew" -o -name "*.pacsave" | xargs sudo rm;

# Reboot
clear
printf "Do you want to reboot?"

if confirm; then
    reboot
else
    clear
fi

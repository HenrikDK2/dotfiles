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

# Add host to /etc/hosts file
echo 127.0.0.1 localhost $(hostname) | sudo tee /etc/hosts

# Enable multilib, DisableDownloadTimeout, and ParallelDownloads
if ! grep -q "DisableDownloadTimeout" "/etc/pacman.conf"; then
	sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
	sudo sed -i "/ParallelDownloads/c\ParallelDownloads = 10\nDisableDownloadTimeout" /etc/pacman.conf
	sudo pacman -Suuy
fi

# Install required packages for building/scripts
sudo pacman -S base-devel bc curl jq --noconfirm --needed

# Makepkg related packages (Flags in ~/.makepkg.conf)
sudo pacman -S mold zstd pigz pbzip2 xz --noconfirm --needed

# Install yay
if [ -z "$(pacman -Qe | grep yay)" ]; then
	git clone https://aur.archlinux.org/yay.git
	sudo chmod 777 -R ./yay
	(cd yay && makepkg -si --noconfirm)
	rm -rf ./yay
fi

# Config settings for Heroic Games Launcher
if [ ! -d "$HOME/.config/heroic" ]; then
	cp -r $HOME/.my_scripts/init/heroic $HOME/.config
	sed -i "s/#NAME/$USER/" $HOME/.config/heroic/config.json
fi

# Sort fastest mirrors weekly
$HOME/.my_scripts/init/scripts/mirrors.sh

# Improve ext4 performance
$HOME/.my_scripts/init/scripts/ext4_optimizations.sh

# Avoid stalls on memory allocations
$HOME/.my_scripts/init/scripts/avoid_stalls_memory.sh

# Add bootloader entries, and install kernel
$HOME/.my_scripts/init/scripts/bootloader.sh

# Enable AMD overclocking service/script
$HOME/.my_scripts/init/scripts/amd_oc.sh

# Android Development
$HOME/.my_scripts/init/scripts/android_development.sh

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
	sed -i "s|/home/henrik|$HOME|g" $HOME/.mozilla/firefox/vem3poti.dev-edition-default/extensions.json
	sed -i "s|/home/henrik|$HOME|g" $HOME/.mozilla/firefox/vem3poti.dev-edition-default/prefs.js
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
    sudo pacman -S blueman bluez-utils --needed --noconfirm;
    sudo systemctl enable --now bluetooth.service;
    echo 'power on' | bluetoothctl;
fi

# Packages
$HOME/.my_scripts/init/scripts/packages.sh

# Make user part of the games group (Allows proton to set niceness of process)
sudo usermod -a -G games $(whoami)

# Change default, and current user shell to fish
sudo chsh -s /bin/fish && sudo chsh -s /bin/fish $(whoami)

# Enable UFW and add firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo sed -i 's/echo-request -j ACCEPT/echo-request -j DROP/' /etc/ufw/before.rules
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
sudo systemctl enable ufw cups dnsmasq denyhosts fstrim.timer
systemctl --user enable wireplumber

# Disable services
systemctl --user mask at-spi-dbus-bus
sudo systemctl mask systemd-userdbd systemd-userdbd.socket accounts-daemon rtkit-daemon ldconfig upower systemd-resolved connman-vpn

# Remove initial pacsave/pacnew files
sudo find /etc -name "*.pacnew" -o -name "*.pacsave" | xargs sudo rm;

# Reboot
for i in {5..1}; do echo "Rebooting in $i..."; sleep 1; done; reboot

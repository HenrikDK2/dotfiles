#!/bin/sh

# Enable multilib pacman and ParallelDownloads
multilibLine=$(grep -n "\[multilib\]" /etc/pacman.conf | cut -d":" -f1)
let "multilibIncludeLine = $multilibLine + 1"
sudo sed -i "${multilibLine}s|#||" /etc/pacman.conf
sudo sed -i "${multilibIncludeLine}s|#||" /etc/pacman.conf
sudo sed -i "/ParallelDownloads/c\ParallelDownloads = 10" /etc/pacman.conf

# Makepkg tweaks - Optimize compiled code
sudo sed -i '/MAKEFLAGS=/c\MAKEFLAGS="-j$(nproc)"' /etc/makepkg.conf
sudo sed -i 's/-march=x86-64/-march=native/' /etc/makepkg.conf
sudo sed -i 's/-mtune=generic/-mtune=native/' /etc/makepkg.conf

# Disable faillock - Annoying
sudo sed -i 's/# deny = 3/deny = 0/g' /etc/security/faillock.conf

# Copy Sudo and Polkit rules
sudo cp -r ~/.my_scripts/init/sudoers.d/* /etc/sudoers.d
sudo cp -r ~/.my_scripts/init/polkit-1/* /etc/polkit-1

# Only allow root to write gamemode scripts
sudo chown root:root ~/.my_scripts/gamemode/*
sudo chmod +wrx ~/.my_scripts/gamemode/*
sudo chmod o+xr-w ~/.my_scripts/gamemode/*

# Copy gaming/network tweaks
totalMem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
minFreeKbytes=$(echo |awk "{ print $totalMem*0.025}")
sed -i "s/#MEM/$minFreeKbytes/" ~/.my_scripts/init/tmpfiles.d/tweaks.conf
sudo cp -r ~/.my_scripts/init/tmpfiles.d/* /etc/tmpfiles.d
sed -i "s/$minFreeKbytes/#MEM/" ~/.my_scripts/init/tmpfiles.d/tweaks.conf

# Allow users to change niceness to negative (Gamemode)
if ! sudo grep -Rq "@wheel - nice -20" /etc/security/limits.conf; then
  echo "@wheel - nice -20" | sudo tee -a /etc/security/limits.conf > /dev/null
fi

# If home directory is not my default, replace it
if [ "$HOME" != "/home/henrik" ]; then
	sudo sed -i "s|/home/henrik|$HOME|g" /etc/sudoers.d/config
	sed -i "s|/home/henrik|$HOME|g" ~/.config/gamemode.ini
fi

# Seahorse keyring
if ! sudo grep -Rq "pam_gnome_keyring.so" /etc/pam.d/login; then
	echo "auth	optional	pam_gnome_keyring.so" | sudo tee -a /etc/pam.d/login
	echo "session    optional pam_gnome_keyring.so     auto_start" | sudo tee -a /etc/pam.d/login
fi

if ! sudo grep -Rq "pam_gnome_keyring.so" /etc/pam.d/passwd; then
	echo "password	optional	pam_gnome_keyring.so" | sudo tee -a /etc/pam.d/passwd
fi

# Find the fastest mirrors
if [ -z "$(pacman -Qe | grep reflector)" ]; then
    sudo pacman -Syu reflector --noconfirm
    sudo reflector --verbose -l 30 -n 5 --sort rate -p https --connection-timeout 3 --download-timeout 3 --save /etc/pacman.d/mirrorlist
fi

# Install building tools
sudo pacman -Syu base-devel --noconfirm

# Install yay
if [ -z "$(pacman -Qe | grep yay)" ]; then
	git clone https://aur.archlinux.org/yay.git
	sudo chmod 777 -R ./yay
	(cd yay && makepkg -si --noconfirm)
	rm -rf ./yay
fi

# fstab tweaks
if ! sudo grep -Rq "rw,noatime,nodiratime,discard" /etc/fstab; then
    clear
    while true; do
        printf "Do you wish to add sdd/hdd tweaks to fstab?\n\n"
        read -p "Drive failures will cause loss of data, will you continue? [y/n] " yn
        case $yn in
            [Yy]* ) sudo sed -i "s/rw,/rw,noatime,nodiratime,discard,/g" /etc/fstab; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

# Add bootloader entries, and install kernel
clear
while true; do
    printf "Only for systemd-boot! - Add bootloader entries?\n\n"
    read -p "This includes kernel hardening, hibernation, ucode, tweaks and unlock access to AMD overclocking [y/n] "  yn
    case $yn in
        [Yy]* ) source ~/.my_scripts/init/bootloader.sh; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Ultrawide gaps on workspace 1
clear
while true; do
    printf "Only for 5120x1440 ultrawide monitor!\n\n"
    read -p "Do you want to have a 1440p window in the center of workspace 1? [y/n] " yn
    case $yn in
        [Yy]* ) mkdir ~/.config/sway/config.d
                cp ~/.my_scripts/init/config.d/workspace-gaps ~/.config/sway/config.d/workspace-gaps; break;;
        [Nn]* ) rm -rf ~/.config/sway/config.d/workspace-gaps; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Optimized Firefox profile
clear
while true; do
    printf "Do you wish to use an optimized Firefox profile?\n\n"
    printf "It disables telemetry, animations and more for privacy and performance.\n\n"
    read -p "This will reset your current profile? [y/n] " yn
    case $yn in
        [Yy]* ) rm -rf ~/.mozilla; cp -r ~/.my_scripts/init/.mozilla ~/.mozilla; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Install Virt-manager
clear
while true; do
    printf "This is for virtual machines.\n\n"
    read -p "Do you want to install virt-manager? [y/n] " yn
    case $yn in
        [Yy]* ) yay -Syu virt-manager qemu-desktop libvirt edk2-ovmf dnsmasq iptables-nft dmidecode --noconfirm;
				sudo systemctl enable --now libvirtd virtlogd;
				sudo usermod -a -G libvirt $(whoami);  break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# General packages
yay -Syu gamemode lib32-gamemode ufw cups irqbalance glxinfo vulkan-tools cmst openvr lib32-gtk2 lib32-libva lib32-libvdpau qt5-declarative qt6-declarative curl qt5-wayland qt6-wayland fish fisher gtklock mako btop man-db swayidle xdg-desktop-portal gperftools lib32-gperftools gnome-keyring polkit polkit-gnome seahorse libsecret imv xdg-desktop-portal-wlr glxinfo sway deluge deluge-gtk xorg-xwayland wofi scrot micro pavucontrol nemo nemo-fileroller npm kitty gamescope firefox-developer-edition gvfs gvfs-mtp code wl-clipboard unrar waybar unzip evolution evolution-ews wayland-protocols tesseract-data-eng tesseract-data-dan --noconfirm

# Mesa drivers
if [ -n "$(glxinfo | grep 'Vendor: AMD')" ]; then
	yay -Syu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils --noconfirm;
	sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf;
	sudo mkinitcpio -P;
elif [ -n "$(glxinfo | grep 'Vendor: Intel')" ]; then
	yay -Syu mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver --noconfirm;
fi

# Sync browser to ram
sudo pacman -Syu profile-sync-daemon glib2 --noconfirm

# Pipewire
yay -Syu wireplumber libpipewire02 pipewire pipewire-alsa pipewire-pulse pipewire-v4l2 --noconfirm

# OBS with game capture
yay -Syu obs-studio obs-vkcapture obs-gstreamer --noconfirm

# Screenshot (Printscreen)
mkdir ~/Screenshots && yay -Syu slurp swappy grim --noconfirm

# Install vscode plugins
~/.my_scripts/init/code-extensions.sh

# Fonts
yay -Syu adobe-source-serif-fonts cantarell-fonts otf-font-awesome ttf-mac-fonts ttf-google-fonts-git ttf-ms-fonts --noconfirm

# Install nvm
fisher install edc/bass
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash

# Change default, and current user shell to fish
sudo chsh -s /bin/fish && sudo chsh -s /bin/fish $(whoami)

# Enable UFW and add firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo sed -i 's/-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT/-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/' /etc/ufw/before.rules
sudo sed -i 's/#Port 22/Port 1065/' /etc/ssh/sshd_config
sudo ufw limit 1065/tcp #SSH
sudo ufw allow 631/tcp #CUPS (printer)
sudo ufw allow ftp/tcp
sudo ufw allow http/tcp
sudo ufw allow https/tcp
sudo ufw logging off
sudo ufw enable

# Clock sync
sudo timedatectl set-ntp true

# Replace tty issue
cat ~/.my_scripts/init/issue.txt | sudo tee /etc/issue

# Enable services
sudo systemctl enable --now ufw cups irqbalance
systemctl --user enable --now wireplumber psd

# Disable services
systemctl --user mask at-spi-dbus-bus gvfs-metadata evolution-addressbook-factory
sudo systemctl mask rtkit-daemon ldconfig.service upower

# Reboot
clear
while true; do
    read -p "Do you want to reboot? [y/n] " yn
    case $yn in
        [Yy]* ) reboot; break;;
        [Nn]* ) clear; break;; 
        * ) echo "Please answer yes or no.";;
    esac
done

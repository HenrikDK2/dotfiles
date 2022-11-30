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
sudo cp -R ~/.my_scripts/init/polkit-1/* /etc/polkit-1

# Only allow root to write gamemode scripts
sudo chown root:root ~/.my_scripts/gamemode/*
sudo chmod +wrx ~/.my_scripts/gamemode/*
sudo chmod o+xr-w ~/.my_scripts/gamemode/*

# Copy gaming/network tweaks
totalMem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
minFreeKbytes=$(echo |awk "{ print $totalMem*0.025}")
sed -i "s/#MEM/$minFreeKbytes/" ~/.my_scripts/init/tmpfiles.d/tweaks.conf
sudo cp -R ~/.my_scripts/init/tmpfiles.d/* /etc/tmpfiles.d
sed -i "s/$minFreeKbytes/#MEM/" ~/.my_scripts/init/tmpfiles.d/tweaks.conf

# Allow users to change niceness to negative (Gamemode)
if ! sudo grep -Rq "@wheel - nice -20" /etc/security/limits.conf; then
  echo "@wheel - nice -20" | sudo tee -a /etc/security/limits.conf > /dev/null
fi

# fstab tweaks
if ! sudo grep -Rq "rw,noatime" /etc/fstab; then
    clear
    while true; do
        echo "Do you wish to add sdd/hdd tweaks to fstab?"
        read -p "Drive failures will cause loss of data, will you continue? [y/n] " yn
        case $yn in
            [Yy]* ) sudo sed -i "s/rw,/rw,noatime,nodiratime,discard,/g" /etc/fstab; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
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

# Install building tools
if [ -z "$(pacman -Qg | grep base-devel)" ]; then
	sudo pacman -Syu base-devel --noconfirm
fi

# Install yay
if [ -z "$(pacman -Qe | grep yay)" ]; then
	git clone https://aur.archlinux.org/yay.git
	sudo chmod 777 -R ./yay
	(cd yay && makepkg -si --noconfirm)
	rm -rf ./yay
fi

# Add bootloader entries, and install kernel
clear
while true; do
    read -p "Only for systemd-boot! - Add bootloader entries with tweaks? [y/n] " yn
    case $yn in
        [Yy]* ) source ~/.my_scripts/init/bootloader.sh; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Ultrawide gaps on workspace 1
clear
while true; do
    echo "Do you have a 5120x1440 ultrawide monitor,"
    read -p "and do you want to have a 1440p window in the center of workspace 1? [y/n] " yn
    if [[ "$yn" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        mkdir cp ~/.config/sway/config.d
        cp ~/.my_scripts/init/config.d/workspace-gaps ~/.config/sway/config.d/workspace-gaps 
        break;
    elif [[ "$yn" =~ ^([nN])$ ]]; then
        rm -rf ~/.config/sway/config.d/workspace-gaps 
        break;
    else
       echo "Please answer yes or no."
    fi
done

# Optimized Firefox profile
clear
while true; do
    echo "Do you wish to use an optimized Firefox profile?"
    echo "It disables telemetry, animations and more for privacy and performance."
    read -p "This will reset your current profile? [y/n] " yn
    case $yn in
        [Yy]* ) rm -rf ~/.mozilla; cp -r ~/.my_scripts/init/.mozilla ~/.mozilla; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Mesa drivers for AMD
clear
while true; do
    read -p "Do you have an AMD gpu? [y/n] " yn
    case $yn in
        [Yy]* ) 
        		yay -Syu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils --noconfirm;
        		sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf;
                sudo mkinitcpio -P; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no." ;;
    esac
done

# General packages
yay -Syu gamemode lib32-gamemode ufw cups irqbalance vulkan-tools cmst openvr lib32-gtk2 lib32-libva lib32-libvdpau qt5-declarative qt6-declarative curl qt5-wayland qt6-wayland fish fisher gtklock mako btop man-db swayidle xdg-desktop-portal gperftools lib32-gperftools gnome-keyring polkit-gnome seahorse libsecret imv xdg-desktop-portal-wlr glxinfo sway deluge deluge-gtk xorg-xwayland wofi scrot micro pavucontrol nemo nemo-fileroller npm kitty gamescope firefox-developer-edition gvfs gvfs-mtp code wl-clipboard unrar waybar unzip evolution evolution-ews wayland-protocols tesseract-data-eng tesseract-data-dan --noconfirm

# Sync browser to ram
sudo pacman -Syu profile-sync-daemon glib2 --noconfirm

# Pipewire
yay -Syu wireplumber libpipewire02 pipewire pipewire-alsa pipewire-pulse pipewire-v4l2 --noconfirm

# OBS with game capture
yay -Syu obs-studio obs-vkcapture obs-gstreamer --noconfirm

# Screenshot (Printscreen)
yay -Syu slurp swappy grim --noconfirm
mkdir ~/Screenshots

# Install vscode plugins
~/.my_scripts/init/code-extensions.sh

# Fonts
yay -Syu adobe-source-serif-fonts cantarell-fonts otf-font-awesome ttf-mac-fonts ttf-google-fonts-git ttf-ms-fonts --noconfirm

# Install nvm
fisher install edc/bass
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash

# Change default shell to fish
sudo chsh -s /bin/fish

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
sudo systemctl enable ufw
sudo systemctl enable cups
sudo systemctl enable irqbalance 
systemctl --user enable wireplumber
systemctl --user enable psd

# Disable services
systemctl --user mask at-spi-dbus-bus
systemctl --user mask gvfs-metadata
systemctl --user mask evolution-addressbook-factory
sudo systemctl mask rtkit-daemon
sudo systemctl mask ldconfig.service
sudo systemctl mask upower

# Reboot
clear
while true; do
    read -p "Do you want to reboot? [y/n] " yn
    case $yn in
        [Yy]* ) reboot; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done
clear
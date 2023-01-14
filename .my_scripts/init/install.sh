#!/bin/sh

# Install building tools
sudo pacman -Syu base-devel --noconfirm --needed

# Enable multilib pacman and ParallelDownloads
multilibLine=$(grep -n "\[multilib\]" /etc/pacman.conf | cut -d":" -f1)
let "multilibIncludeLine = $multilibLine + 1"
sudo sed -i "${multilibLine}s|#||" /etc/pacman.conf
sudo sed -i "${multilibIncludeLine}s|#||" /etc/pacman.conf
sudo sed -i "/ParallelDownloads/c\ParallelDownloads = 10" /etc/pacman.conf

# Makepkg tweaks - Optimize compiled code
sudo pacman -S zstd pigz pbzip2 xz --noconfirm --needed
sudo sed -i '/MAKEFLAGS=/c\MAKEFLAGS="-j$(nproc)"' /etc/makepkg.conf
sudo sed -i 's/-march=x86-64/-march=native/' /etc/makepkg.conf
sudo sed -i 's/-mtune=generic/-mtune=native/' /etc/makepkg.conf
sudo sed -i 's/-O2/-O3 -flto/' /etc/makepkg.conf
sudo sed -i 's/COMPRESSZST.*/COMPRESSZST=(zstd -c -z -q --threads=0 -)/' /etc/makepkg.conf
sudo sed -i 's/COMPRESSXZ.*/COMPRESSXZ=(xz -c -z --threads=0 -)/' /etc/makepkg.conf
sudo sed -i 's/COMPRESSGZ.*/COMPRESSGZ=(pigz -c -f -n)/' /etc/makepkg.conf
sudo sed -i 's/COMPRESSBZ2.*/COMPRESSBZ2=(pbzip2 -c -f)/' /etc/makepkg.conf

# Install yay
if [ -z "$(pacman -Qe | grep yay)" ]; then
	git clone https://aur.archlinux.org/yay.git
	sudo chmod 777 -R ./yay
	(cd yay && makepkg -si --noconfirm)
	rm -rf ./yay
fi

# Use ALHP mirror if supported by the CPU (https://git.harting.dev/ALHP/ALHP.GO)
if [ -z "$(grep -F '[core-x86-64-v3]' /etc/pacman.conf)" ] && [ -n "$(lscpu | grep 'sse4_2')" ]; then
	yay -S alhp-keyring alhp-mirrorlist --noconfirm --needed
	sudo sed -i '/\[core\]/i [core-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n\n[extra-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n\n[community-x86-64-v3]\nInclude = /etc/pacman.d/alhp-mirrorlist\n' /etc/pacman.conf
	sudo pacman -Suy --noconfirm
fi

# Default dconf values
dconf write /org/nemo/window-state/start-with-menu-bar false
dconf write /org/gnome/evolution/shell/menubar-visible false
dconf write /org/gnome/evolution/shell/statusbar-visible false
dconf write /org/gnome/evolution/shell/toolbar-visible false

# Disable faillock - Annoying
sudo sed -i 's/# deny = 3/deny = 0/g' /etc/security/faillock.conf

# Copy Sudo and Polkit rules
sudo cp -r ~/.my_scripts/init/sudoers.d/* /etc/sudoers.d
sudo cp -r ~/.my_scripts/init/polkit-1/* /etc/polkit-1
sudo sed -i "s|/home/henrik|$HOME|g" /etc/sudoers.d/config

# Permissions
sudo chown root:root ~/.my_scripts/gamemode/* /etc/ssh/sshd_config
sudo chmod o+xr-w ~/.my_scripts/gamemode/* /etc/sudoers.d/config

# Systemd timeout
sudo mkdir -p /etc/systemd/system.conf.d/
echo -e "[Manager]\nDefaultTimeoutStopSec=10s" | sudo tee /etc/systemd/system.conf.d/system.conf

# Copy gaming/network tweaks
totalMem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
minFreeKbytes=$(echo |awk "{ print $totalMem*0.025}")
sed -i "s/#MEM/$minFreeKbytes/" ~/.my_scripts/init/tmpfiles.d/tweaks.conf
sudo cp -r ~/.my_scripts/init/tmpfiles.d/* /etc/tmpfiles.d
sed -i "s/$minFreeKbytes/#MEM/" ~/.my_scripts/init/tmpfiles.d/tweaks.conf

# Allow users to change niceness to negative (Gamemode)
if ! sudo grep -Rq "@wheel - nice -20" /etc/security/limits.conf; then
  echo "@wheel - nice -20" | sudo tee -a /etc/security/limits.conf
fi

# Disable core cumps for setuid and setgid programs
if ! sudo grep -Rq "*  hard  core  0" /etc/security/limits.conf; then
  echo "*  hard  core  0" | sudo tee -a /etc/security/limits.conf
fi

# Git configuration
git config --global init.defaultBranch master

if [ -z "$(git config --global --list | grep -oP '(?<=user.name=).*')" ]; then
	clear
	printf "What is your git username? \n\n"
	read -p "You can type \"none\", if you don't want to set one globally: " name
	if [ "$name" != "none"  ] && [ -n "$name" ]; then
		git config --global user.name "$name"
	fi
fi

if [ -z "$(git config --global --list | grep -oP '(?<=user.email=).*')" ]; then
	clear
	printf "What is your git email? \n\n"
	read -p "You can type \"none\", if you don't want to set one globally: " email
	if [ "$email" != "none"  ] && [ -n "$email" ]; then
		git config --global user.email "$email"
	fi
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
    sudo pacman -S reflector --noconfirm --needed
    sudo reflector --verbose -l 30 -n 5 --sort rate -p https --connection-timeout 3 --download-timeout 3 --save /etc/pacman.d/mirrorlist
fi

# fstab tweaks
clear
if ! sudo grep -Rq "rw,noatime,nodiratime,discard" /etc/fstab; then
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
while true; do
    clear
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
        [Yy]* ) yay -S virt-manager qemu-desktop libvirt edk2-ovmf iptables-nft dmidecode --needed;
				sudo systemctl enable --now libvirtd virtlogd;
				sudo usermod -a -G libvirt $(whoami);  break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Fonts
yay -S adobe-source-serif-fonts cantarell-fonts otf-font-awesome ttf-mac-fonts ttf-google-fonts-git ttf-ms-fonts --noconfirm --needed

# Pipewire
yay -S wireplumber libpipewire02 pipewire gst-plugin-pipewire pipewire-alsa pipewire-pulse pipewire-v4l2 --noconfirm --needed

# General packages
yay -S gamemode lib32-gamemode ufw cups irqbalance mesa-utils glxinfo vulkan-tools cmst mpv wget dnsmasq openvr lib32-gtk2 lib32-libva lib32-libvdpau qt5-declarative qt6-declarative curl qt5-wayland qt6-wayland fish fisher gtklock mako btop man-db swayidle swaybg xdg-desktop-portal gperftools lib32-gperftools gnome-keyring polkit polkit-gnome seahorse libsecret imv xdg-desktop-portal-wlr glxinfo sway deluge deluge-gtk xorg-xwayland wofi scrot micro pavucontrol nemo nemo-fileroller npm kitty gamescope firefox-developer-edition gvfs gvfs-mtp visual-studio-code-bin wl-clipboard unrar waybar libappindicator-gtk2 libappindicator-gtk3 unzip evolution evolution-ews wayland-protocols tesseract-data-eng --noconfirm --needed

# Mesa drivers
vendor="$(glxinfo -B | grep -o 'Vendor: [^ ]*')"

if [[ "$vendor" != "Vendor: NVIDIA" ]]; then
    if [[ "$vendor" == "Vendor: AMD" ]]; then
        yay -S mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils --noconfirm --needed
        sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    elif [[ "$vendor" == "Vendor: Intel" ]]; then
        yay -S mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver --noconfirm --needed
    fi
fi

# MangoHud
yay -S mangohud mangohud-common lib32-mangohud --noconfirm --needed

# Sync browser to ram
sudo pacman -S profile-sync-daemon glib2 --noconfirm --needed

# OBS with game capture
yay -S obs-studio obs-vkcapture obs-gstreamer --noconfirm --needed

# Screenshot (Printscreen)
mkdir ~/Screenshots && yay -S slurp swappy grim --noconfirm --needed

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

# Setup dnsmasq
sudo cp -r ~/.my_scripts/init/dns/* /etc/

# Denyhosts (Unified hosts file for ads, tracking, malware, ransomware every week or on boot)
sudo cp -r ~/.my_scripts/init/denyhosts/* /
sudo chown root:root /usr/bin/denyhosts.sh  /etc/systemd/system/denyhosts.service
sudo chmod o+xr-w /usr/bin/denyhosts.sh  /etc/systemd/system/denyhosts.service

# Clock sync
sudo timedatectl set-ntp true

# Replace tty issue
cat ~/.my_scripts/init/issue.txt | sudo tee /etc/issue

# Enable services
sudo systemctl enable ufw cups dnsmasq irqbalance denyhosts
systemctl --user enable wireplumber psd

# Disable services
systemctl --user mask at-spi-dbus-bus gvfs-metadata evolution-addressbook-factory
sudo systemctl mask rtkit-daemon ldconfig.service upower systemd-resolved connman-vpn

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

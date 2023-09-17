#!/bin/sh

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

# Reflector - Find the fastest mirrors
if [ -z "$(pacman -Qe | grep reflector)" ]; then
	sudo pacman -S reflector --noconfirm --needed
	sudo reflector --verbose --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
	sudo systemctl enable reflector.timer # Update mirrorlist weekly
fi

# Install building tools and awk
sudo pacman -Syu base-devel gawk --noconfirm --needed

# Install yay
if [ -z "$(pacman -Qe | grep yay)" ]; then
	git clone https://aur.archlinux.org/yay.git
	sudo chmod 777 -R ./yay
	(cd yay && makepkg -si --noconfirm)
	rm -rf ./yay
fi

# Copy system files
sudo cp -r ~/.my_scripts/init/system/* /

# Enable multilib, and ParallelDownloads
multilibLine=$(grep -n "\[multilib\]" /etc/pacman.conf | cut -d":" -f1)
let "multilibIncludeLine = $multilibLine + 1"
sudo sed -i "${multilibLine}s|#||" /etc/pacman.conf
sudo sed -i "${multilibIncludeLine}s|#||" /etc/pacman.conf
sudo sed -i "/ParallelDownloads/c\ParallelDownloads = 10" /etc/pacman.conf

# Makepkg related packages (Flags in ~/.makepkg.conf)
sudo pacman -S mold zstd pigz pbzip2 xz --noconfirm --needed

# Default dconf values
sudo pacman -S dconf --noconfirm --needed 
dconf write /org/nemo/window-state/start-with-menu-bar false
dconf write /org/gnome/evolution/shell/menubar-visible false
dconf write /org/gnome/evolution/shell/statusbar-visible false
dconf write /org/gnome/evolution/shell/toolbar-visible false
dconf write /org/gnome/evolution/mail/show-preview-toolbar false
dconf write /org/gnome/evolution/shell/buttons-style "'icons'"
dconf write /org/gnome/evolution/shell/toolbar-icon-size "'small'"

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
        [Yy]* ) yay -S virt-manager qemu-desktop libvirt edk2-ovmf iptables-nft dmidecode --needed;
				sudo systemctl enable --now libvirtd virtlogd;
				sudo usermod -a -G libvirt $(whoami);  break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Setup bluetooth
clear
while true; do
	printf "This is for bluetooth.\n\n"
    read -p "Do you want to install blueman? [y/n] " yn
    case $yn in
        [Yy]* ) sudo pacman -S blueman --needed --noconfirm;
        		sudo systemctl enable --now bluetooth.service; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Mesa drivers - AMD/Intel
if [ ! -z  "$(lspci -vnn | grep VGA -A 12 | grep -i amdgpu)" ]; then
    clear
    while true; do
        read -p "Do you want to install Mesa drivers for AMD? [y/n] " yn
        case $yn in
            [Yy]* ) yay -Syu mesa-amdonly-gaming-git lib32-mesa-amdonly-gaming-git --needed --noconfirm
                    sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf
                    sudo mkinitcpio -P; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ ! -z "$(lspci -vnn | grep VGA -A 12 | grep -i Intel)" ]]; then
    clear
    while true; do
        read -p "Do you want to install Mesa drivers for Intel? [y/n] " yn
        case $yn in
            [Yy]* ) yay -Syu mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

# Fonts
yay -S adobe-source-serif-fonts cantarell-fonts otf-font-awesome ttf-mac-fonts ttf-google-fonts-git ttf-ms-fonts --needed

# Packages
sudo pacman -S mangohud lib32-mangohud --noconfirm --needed
yay -S btop cabextract fuse cmst cups curl dbus-broker deluge deluge-gtk dnsmasq evolution evolution-ews firefox-developer-edition fish fisher gamemode gamescope glib2 glxinfo gnome-keyring gperftools grim gtklock gvfs gvfs-mtp imv steam discord irqbalance kitty linux-firmware lib32-gamemode pipewire pipewire-audio pipewire-pulse pipewire-alsa pipewire-jack wireplumber lib32-gperftools lib32-gtk2 lib32-libva lib32-libvdpau libappindicator-gtk2 libappindicator-gtk3 libsecret mako man-db micro mpv nemo nemo-fileroller nemo-preview npm obs-gstreamer obs-studio obs-vkcapture openvr p7zip pavucontrol pciutils polkit polkit-gnome profile-sync-daemon qt5-declarative qt5-wayland qt6-declarative qt6-wayland scrot seahorse slurp swappy sway swaybg swayidle tesseract-data-eng ufw unrar unzip util-linux code vulkan-tools waybar wayland-protocols wget wine wine-gecko wine-mono wl-clipboard wofi xdg-desktop-portal xdg-desktop-portal-wlr xorg-xwayland --needed

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
sudo systemctl enable ufw cups dnsmasq irqbalance denyhosts dbus-broker optimize-interruptfreq fstrim.timer
systemctl --user enable wireplumber psd dbus-broker

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

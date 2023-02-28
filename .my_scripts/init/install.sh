#!/bin/sh

# Find the fastest mirrors
if [ -z "$(pacman -Qe | grep reflector)" ]; then
    sudo pacman -S reflector --noconfirm --needed
    sudo reflector --verbose -l 30 -n 5 --sort rate -p https --connection-timeout 3 --download-timeout 3 --save /etc/pacman.d/mirrorlist
fi

# Install building tools
sudo pacman -Syu base-devel git sudo --noconfirm --needed

# Install yay
if [ -z "$(pacman -Qe | grep yay)" ]; then
	git clone https://aur.archlinux.org/yay.git
	sudo chmod 777 -R ./yay
	(cd yay && makepkg -si --noconfirm)
	rm -rf ./yay
fi

# Copy system files
sudo cp -r ~/.my_scripts/init/system/* /

# Enable multilib, and ParallelDownloads, and add mirrorlists
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

# Default dconf values
dconf write /org/nemo/window-state/start-with-menu-bar false
dconf write /org/gnome/evolution/shell/menubar-visible false
dconf write /org/gnome/evolution/shell/statusbar-visible false
dconf write /org/gnome/evolution/shell/toolbar-visible false

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
yay -S adobe-source-serif-fonts cantarell-fonts otf-font-awesome ttf-mac-fonts ttf-google-fonts-git ttf-ms-fonts --needed

# Packages
yay -S btop cmst cups curl cabextract deluge deluge-gtk dnsmasq dbus-broker evolution evolution-ews firefox-developer-edition fish fisher gamemode gamescope glib2 glxinfo gnome-keyring gperftools grim gst-plugin-pipewire gtklock gvfs gvfs-mtp imv irqbalance kitty lib32-gamemode lib32-gperftools lib32-gtk2 lib32-libva lib32-libvdpau lib32-mangohud libappindicator-gtk2 libappindicator-gtk3 libpipewire02 libsecret mako man-db mangohud mangohud-common mesa-utils micro mpv nemo nemo-fileroller npm obs-gstreamer obs-studio obs-vkcapture openvr p7zip pavucontrol pciutils pipewire pipewire-alsa pipewire-pulse pipewire-v4l2 polkit polkit-gnome profile-sync-daemon qt5-declarative qt5-wayland qt6-declarative qt6-wayland scrot seahorse slurp swappy sway swaybg swayidle tesseract-data-eng util-linux ufw unrar unzip visual-studio-code-bin vulkan-tools wine wine-gecko wine-mono waybar wayland-protocols wget wireplumber wl-clipboard wofi xdg-desktop-portal xdg-desktop-portal-wlr xorg-xwayland --needed

# Mesa drivers - AMD/Intel
if [ ! -z  "$(lspci -vnn | grep VGA -A 12 | grep amdgpu)" ]; then
    clear
    while true; do
        read -p "Do you want to install Mesa drivers for AMD? [y/n] " yn
        case $yn in
            [Yy]* ) yay -Syu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils
                    sudo sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf
                    sudo mkinitcpio -P; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ ! -z "$(lspci -vnn | grep VGA -A 12 | grep Intel)" ]]; then
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

# Enable services
sudo systemctl enable ufw cups dnsmasq irqbalance denyhosts dbus-broker optimize-interruptfreq pci-latency fstrim.timer
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

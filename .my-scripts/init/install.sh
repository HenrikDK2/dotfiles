#!/bin/sh

name=$(whoami)

# Enable multilib pacman and ParallelDownloads
multilibLine=$(grep -n "\[multilib\]" /etc/pacman.conf | cut -d":" -f1)
let "multilibIncludeLine = $multilibLine + 1"
sudo sed -i "${multilibLine}s|#||" /etc/pacman.conf
sudo sed -i "${multilibIncludeLine}s|#||" /etc/pacman.conf
sudo sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 10/g" /etc/pacman.conf

# Makepkg tweaks - Optimize compiled code
sudo sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
sudo sed -i 's/-march=x86-64/-march=native/' /etc/makepkg.conf
sudo sed -i 's/-mtune=generic/-mtune=native/' /etc/makepkg.conf

clear
while true; do
    echo "Do you want to add Link Time Optimization (LTO) to all compiled packages?"
    read -p "This might increase runtime performance, but at the cost of compile speed [y/n] " yn
    case $yn in
        [Yy]* ) sudo sed -i 's/-O2/-O3 -flto/g' /etc/makepkg.conf; sudo sed -i 's/LDFLAGS="-Wl,-01,/LDFLAGS="-Wl,-O3,-flto,/' /etc/makepkg.conf; break;;
        [Nn]* ) sudo sed -i 's/-O2/-O3/g' /etc/makepkg.conf; sudo sed -i 's/LDFLAGS="-Wl,-01,/LDFLAGS="-Wl,-O3,/' /etc/makepkg.conf; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Disable faillock - Annoying
sudo sed -i 's/# deny = 3/deny = 0/g' /etc/security/faillock.conf

# Copy polkit rules
sudo cp -R ~/.my-scripts/init/polkit-1/* /etc/polkit-1

# Copy network tweaks
sudo cp -R ~/.my-scripts/init/sysctl.d/* /etc/sysctl.d

# Sudo tweaks
if ! sudo grep -Rq "%wheel ALL = NOPASSWD: /home/$name/.my-scripts/free-os-cache.sh" /etc/sudoers
then
	echo "Defaults env_reset,passwd_tries=10,timestamp_timeout=120" | sudo tee -a /etc/sudoers
	echo "%wheel ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
	echo "%wheel ALL = NOPASSWD: /home/$name/.my-scripts/free-os-cache.sh" | sudo tee -a /etc/sudoers
	echo "%wheel ALL = NOPASSWD: /usr/bin/psd-overlay-helper" | sudo tee -a /etc/sudoers
fi

# Allow users to change niceness to negative (Gamemode)
if ! sudo grep -Rq "@wheel - nice -20" /etc/security/limits.conf
then
  echo "@wheel - nice -20" | sudo tee -a /etc/security/limits.conf > /dev/null
fi

# fstab tweaks
if ! sudo grep -Rq "rw,noatime" /etc/fstab
then
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

# If username isn't the same as Henrik, replace name in these files
if [ "$name" != "henrik" ]; then
	sudo sed -i "s/henrik/$name/g" /etc/sudoers
	sed -i "s/henrik/$name/g" ~/.config/gamemode.ini
fi

# Seahorse keyring
if ! sudo grep -Rq "pam_gnome_keyring.so" /etc/pam.d/login
then
	echo "auth	optional	pam_gnome_keyring.so" | sudo tee -a /etc/pam.d/login
	echo "session    optional pam_gnome_keyring.so     auto_start" | sudo tee -a /etc/pam.d/login
    clear
fi

if ! sudo grep -Rq "pam_gnome_keyring.so" /etc/pam.d/passwd
then
	echo "password	optional	pam_gnome_keyring.so" | sudo tee -a /etc/pam.d/passwd
    clear
fi

# Install building tools
sudo pacman -Syu base-devel --noconfirm

# Install yay
cd /opt
sudo git clone https://aur.archlinux.org/yay-git.git
sudo chmod 777 -R ./yay-git
cd yay-git
makepkg -si --noconfirm

# Clear cache
yay -Scc --noconfirm

# Add bootloader entries, and install kernel
clear
while true; do
    read -p "Only for systemd-boot! - Add bootloader entries with tweaks? [y/n] " yn
    case $yn in
        [Yy]* ) source ~/.my-scripts/init/bootloader.sh; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Ultrawide gaps on workspace 1
clear
while true; do
    echo "Do you have a 5120x1440 ultrawide monitor,"
    read -p "and do you want to have a 1440p window in the center on workspace 1? [y/n] " yn
    if [[ "$yn" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        if ! grep -Rq "workspace 1 gaps horizontal 1280" ~/.config/sway/config
        then
            sed '/^#Workspace 1 gaps$/r'<(
                echo "workspace 1 gaps inner 0"
                echo "workspace 1 gaps horizontal 1280"
                echo "workspace 1 gaps top 0"
            ) -i -- ~/.config/sway/config
        fi
        break;
    elif [[ "$yn" =~ ^([nN])$ ]]; then
        sed -i '/workspace 1 gaps inner 0/d' ~/.config/sway/config
        sed -i '/workspace 1 gaps horizontal 1280/d' ~/.config/sway/config
        sed -i '/workspace 1 gaps top 0/d' ~/.config/sway/config
        break;
    else
       echo "Please answer yes or no."
    fi
done

# Optimized Firefox profile
clear
while true; do
    echo "Do you wish to use an optimized Firefox profile?"
    read -p "This will reset your current profile? [y/n] " yn
    case $yn in
        [Yy]* ) rm -rf ~/.mozilla; cp -r ~/.my-scripts/init/.mozilla ~/.mozilla; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Mesa drivers for AMD
clear
while true; do
    read -p "Do you have an AMD gpu? [y/n] " yn
    case $yn in
        [Yy]* ) yay -Syu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils --noconfirm; break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Sync browser to ram
sudo pacman -S profile-sync-daemon --noconfirm
sudo systemctl --user enable psd

# Pipewire
yay -Syu wireplumber libpipewire02 pipewire pipewire-alsa pipewire-pulse --noconfirm
systemctl --user --now enable wireplumber

# General packages
yay -Syu gamemode lib32-gamemode ufw vulkan-tools cmst openvr lib32-gtk2 lib32-libva lib32-libvdpau qt5-declarative qt6-declarative qt5-wayland qt6-wayland fish swaylock-fancy mako man-db swayidle xdg-desktop-portal gperftools lib32-gperftools gnome-keyring polkit-gnome seahorse libsecret imv xdg-desktop-portal-wlr glxinfo sway deluge deluge-gtk xorg-xwayland wofi sysmontask scrot micro pavucontrol nemo nemo-fileroller npm kitty gamescope firefox gvfs gvfs-mtp code wl-clipboard unrar waybar unzip evolution evolution-ews wayland-protocols --noconfirm

# Screenshot (Printscreen)
yay -Syu slurp swappy grim --noconfirm
mkdir /home/$name/Screenshots

# Install vscode plugins
~/.my-scripts/init/code-extensions.sh

# Fonts
yay -Syu otf-font-awesome ttf-mac-fonts ttf-google-fonts-git ttf-ms-win11-auto ttf-ms-win11-auto-japanese ttf-ms-win11-auto-korean ttf-ms-win11-auto-other ttf-ms-win11-auto-sea ttf-ms-win11-auto-thai ttf-ms-win11-auto-zh_cn ttf-ms-win11-auto-zh_tw --noconfirm

# Change default shell to fish
sudo chsh -s /bin/fish

# Enable UFW and add firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo sed -i 's/#Port 22/Port 1065/' /etc/ssh/sshd_config
sudo ufw allow 1065/tcp
sudo ufw allow ftp/tcp
sudo ufw allow http/tcp
sudo ufw allow https/tcp
sudo ufw logging off
sudo systemctl enable --now ufw
sudo ufw enable

# Theme
gsettings set org.gnome.desktop.interface gtk-theme "Nordic-darker"
gsettings set org.gnome.desktop.interface icon-theme "Tela-nord-dark"
gsettings set org.gnome.desktop.wm.preferences theme "Nordic-darker"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

# Applications - Standard
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty
gsettings set org.gnome.desktop.background show-desktop-icons true
xdg-settings set default-web-browser firefox.desktop
xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search

# Clock sync
sudo timedatectl set-ntp true

# Replace tty issue
cat ~/.my-scripts/init/issue.txt | sudo tee /etc/issue

# Disable Journald
sudo systemctl mask systemd-journald
sudo systemctl mask systemd-journal-catalog-update
sudo sed -i 's/#Storage=auto/Storage=none/' /etc/systemd/journald.conf

# Irqbalance
yay -Syu irqbalance --noconfirm
sudo systemctl enable --now irqbalance 

# Disable services
sudo sed -i 's/Exec=/Exec=#/' /usr/share/dbus-1/services/org.gnome.OnlineAccounts.service
sudo sed -i 's/Exec=/Exec=#/' /etc/xdg/autostart/org.gnome.Evolution-alarm-notify.desktop
sudo sed -i 's/Exec=/Exec=#/' /usr/share/applications/org.gnome.Evolution-alarm-notify.desktop
systemctl --user mask evolution-addressbook-factory
systemctl --user mask at-spi-dbus-bus
systemctl --user mask gvfs-metadata
sudo systemctl mask rtkit-daemon
sudo systemctl mask ldconfig.service
sudo systemctl mask upower
sudo systemctl disable --now systemd-timesyncd


while ! [ "$(pacman -Qdtq)" = "" ]; do
	sudo pacman -Rn $(pacman -Qdtq) --noconfirm
done

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

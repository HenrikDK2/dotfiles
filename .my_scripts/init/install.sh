#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"

packages=(
	"dnf-automatic"
	"code"
	"discord"
	"mangohud"
	"gamescope"
	"NetworkManager-openvpn.x86_64"
	"btop"
	"mpg123"
	"zstd"
)

flathub_packages=(
	"com.mastermindzh.tidal-hifi"
	"com.valvesoftware.Steam"
	"com.valvesoftware.Steam.CompatibilityTool.Proton-GE"
)

packages_to_remove=(
	"libreoffice*"
	"rhythmbox.*"
	"irqbalance"
	"malcontent*"
	"system-config-language.*"
	"nheko.*"
)

###############################
# Copy custom system files
###############################
sudo cp -r $DIR/system/* /

###############################
# Enable custom services
###############################
sudo systemctl enable \
	gameboost.service\
	system-tuning.service\
	unmask-upower.service\
	fstrim.timer

systemctl enable --user flatpak-update.timer

#############################################
# Setup RPM Fusion, and third party repos
#############################################
sudo dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

sudo dnf upgrade -y --refresh

############################
# Install/Remove packages
############################
sudo dnf install -y "${packages[@]}"
flatpak install flathub "${flathub_packages[@]}"
sudo dnf remove -y "${packages_to_remove[@]}"

############################
# Setup automatic updates
############################
sudo cp -f /usr/share/dnf5/dnf5-plugins/automatic.conf /etc/dnf/automatic.conf
sudo sed -i 's/^apply_updates =.*/apply_updates = yes/' /etc/dnf/automatic.conf

############################
# Scripts
############################
# Functions script is reused by other scripts
source "$DIR/scripts/functions.sh"

# Rest
source "$DIR/scripts/code_extensions.sh"
source "$DIR/scripts/heroic.sh"
source "$DIR/scripts/mozilla.sh"
source "$DIR/scripts/drive_optimizations.sh"
source "$DIR/scripts/kernel_params.sh"
source "$DIR/scripts/firewall.sh"
source "$DIR/scripts/amd_oc.sh"

clear_screen
echo "Install DONE! Please reboot system..."

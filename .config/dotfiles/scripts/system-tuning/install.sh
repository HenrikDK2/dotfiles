SCRIPT_DIR="$HOME/.config/dotfiles"
SOURCE_DIR="$SCRIPT_DIR/scripts/system-tuning/root"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found: $SOURCE_DIR" >&2
    exit 1
fi

echo "Installing system-tuning service..."
sudo cp -rf "$SOURCE_DIR/." /

echo "Setting permissions..."
sudo chown root:root \
    /etc/systemd/system/system-tuning.service \
    /var/local/system-tuning.sh
sudo chmod 644 /etc/systemd/system/system-tuning.service
sudo chmod 755 /var/local/system-tuning.sh
sudo semanage fcontext -a -t bin_t "/var/local/system-tuning.sh"
sudo restorecon -v /var/local/system-tuning.sh

echo "Enabling service..."
sudo systemctl enable system-tuning.service

echo "Done."

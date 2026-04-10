#!/bin/bash

REPO_FILE="/etc/yum.repos.d/zerotier.repo"

# Repo setup
if [ ! -f "$REPO_FILE" ]; then
  echo "Adding ZeroTier repo..."
  sudo tee "$REPO_FILE" >/dev/null <<'EOF'
[zerotier]
name=ZeroTier, Inc. RPM Release Repository
baseurl=https://download.zerotier.com/redhat/fc/$releasever
enabled=1
gpgcheck=1
gpgkey=https://download.zerotier.com/contact@zerotier.com.gpg
EOF
fi

# Install check
if rpm-ostree status | grep -qw zerotier-one; then
  echo "zerotier-one already installed"
else
  echo "Installing zerotier-one..."
  sudo rpm-ostree install zerotier-one
fi

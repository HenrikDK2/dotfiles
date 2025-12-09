# dotfiles

![Desktop Screenshot 1](https://github.com/HenrikDK2/dotfiles/assets/30632653/2356ff00-1e85-44dc-a348-05494f9ce953)
![Desktop Screenshot 2](https://github.com/HenrikDK2/dotfiles/assets/30632653/8473e129-bf4c-451b-9a16-22a6d8330f71)

## ⚠️ Critical Warnings

**HARDWARE COMPATIBILITY:** These configurations are specifically designed for **AMD processors and AMD graphics cards** on a **Desktop PC**. If you are using different hardware, these configurations **may have problems** and might not work as expected.

**RISK:** Use these configurations at your own risk. I am not responsible for any issues that may occur from using these files.

## Overview

This repository contains my complete system configuration, including dotfiles and system tweaks. While primarily designed for personal use, you're welcome to adapt these configurations for your own setup.

## Features

- System performance tuned for gaming
- Enhanced system responsiveness
- Security-focused configurations
- Desktop PC / laptop environment tweaks

## Prerequisites

- Fresh Arch Linux installation
- AMD hardware (CPU/GPU)

## Installation

### Before You Begin

**⚠️ Warning:** This installation will overwrite your existing configuration files. Back up any important configurations before proceeding.

### Steps

1. Follow the [Arch Wiki installation guide](https://wiki.archlinux.org/title/Installation_guide) through [section 3.2 (Chroot)](https://wiki.archlinux.org/title/Installation_guide#Chroot)

2. Clone this repository to a temporary location:
   ```bash
   git clone https://github.com/HenrikDK2/dotfiles /tmp/dotfiles
   ```

3. Configure your preferences:
   ```bash
   nano /tmp/dotfiles/.dotfiles/init/env.sh
   ```

4. Run the installation script as root:
   ```bash
   cd /tmp/dotfiles/.dotfiles/init/install.sh
   ```

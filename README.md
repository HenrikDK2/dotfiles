# Bazzite dotfiles

![Desktop Screenshot 1](https://github.com/HenrikDK2/dotfiles/blob/bazzite/.config/dotfiles/assets/desktop.png)

## ⚠️ Critical Warnings

**RISK:** Use these configurations at your own risk. I am not responsible for any issues that may occur from using these files.

## Overview

This repository contains my complete system configuration, including dotfiles and system tweaks. While primarily designed for personal use, you're welcome to adapt these configurations for your own setup.

## Features

- System performance tuned for gaming
- Enhanced system responsiveness
- Security-focused configurations
- Desktop PC / laptop environment tweaks

## Prerequisites

- Fresh Bazzite install

## Installation

### Before You Begin

**⚠️ Warning:** This installation will overwrite your existing configuration files. Back up any important configurations before proceeding.

### Steps

1. **Initialize a git repository** in your home directory:
```bash
   git init $HOME
   git -C $HOME remote add origin git@github.com:HenrikDK2/dotfiles.git
   git -C $HOME fetch origin
   git -C $HOME checkout bazzite --force
```

2. **Run the install script:**
```bash
   bash $HOME/.config/dotfiles/install.sh
```

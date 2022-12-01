# Welcome to my dotfiles

This is for personal usage, but you may gladly use it as well. It includes all of my configuration files, but also tweaks for system files, which I always include on my system for either responsiveness or gaming tweaks when I have to do fresh installations on new systems.

**Any usage of my system/configuration files falls in no way or form under my liability**

## Install

#### What you need to know before installing

- Configuration/system files are only tested on a fresh install of Arch Linux.

- You should have sudo and git installed on your system.

- systemd-boot is recommended, since that is what I use, and a script depends on it for kernel hardening, hibernation, ucode, tweaks and unlock access to AMD overclocking.

- This project only considers my usage on an AMD machine, you might need to do some tweaking to get it working on your machine.

#### Installation guide

Go to your home directory in the terminal, and type the following.

```bash
git init
git remote add origin https://github.com/HenrikDK2/dotfiles.git
git pull
```

Now you're mostly done, you just need to run `~/.my_scripts/init/install.sh`, and follow the simple procedures.

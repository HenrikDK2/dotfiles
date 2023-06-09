# Welcome to my dotfiles

![20230609-162049](https://github.com/HenrikDK2/dotfiles/assets/30632653/f785198b-9339-457e-b58d-5e80eaecf11b)
![20230609-162658](https://github.com/HenrikDK2/dotfiles/assets/30632653/5bf760b1-947b-427d-85a9-d53ae10cf21f)

This is for personal usage, but you may gladly use it as well. It includes all of my configuration files, but also tweaks for system files, which I always include on my system for either responsiveness or gaming tweaks when I have to do fresh installations on new systems.

**Any usage of my system/configuration files falls in no way or form under my liability**

## Install

#### What you need to know before installing

- Configuration/system files are only tested on a fresh install of Arch Linux.

- You should have sudo and git installed on your system.

- systemd-boot is recommended, since that is what I use, and a script depends on it for kernel hardening, hibernation, ucode, tweaks and unlock access to AMD overclocking.

- This project only considers my usage on an AMD machine, you might need to do some tweaking to get it working on your machine.

#### Installation guide

**This is a warning!** Doing the following will replace all files with my configuration files.

Go to your home directory in the terminal, and type the following:

```bash
git init
git remote add origin https://github.com/HenrikDK2/dotfiles.git
git fetch --all
git reset --hard origin/master
```

Now you're mostly done, you just need to run the install script `~/.my_scripts/init/install.sh` as a normal user, and follow the simple procedures.


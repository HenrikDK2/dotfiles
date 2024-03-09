# Welcome to my dotfiles

![20240308-085741](https://github.com/HenrikDK2/dotfiles/assets/30632653/2356ff00-1e85-44dc-a348-05494f9ce953)
![20240308-085940](https://github.com/HenrikDK2/dotfiles/assets/30632653/8473e129-bf4c-451b-9a16-22a6d8330f71)

My dotfiles are intended for personal usage, but feel free to make use of them as well. They include all of my configuration files, along with tweaks for system files. I always incorporate these tweaks on my system to enhance responsiveness, gaming performance, and security, when setting up new systems.

**Please note that any usage of my system/configuration files is done at your own risk. I am not liable for any consequences that may arise.**

## Install

### Important considerations before installing

- These configuration/system files have only been tested on a fresh install of Arch Linux.

- Keep in mind that this project is tailored to my usage on an AMD machine. You may need to make some adjustments to adapt it to your specific hardware.

### Installation guide

**Warning!** Executing the following steps will replace your existing files with my configuration files.

The install script expects Arch Linux to be setup with `sudo`, `git`, `connman`, and `systemd-boot`.

1. Open the terminal and navigate to your home directory.

2. Run the following commands:

   ```
   git init
   git remote add origin https://github.com/HenrikDK2/dotfiles.git
   git fetch --all
   git checkout master --force
   ```

3. Now you're almost done! As a normal user, execute the installation script `~/.my_scripts/init/install.sh` and follow the simple instructions to complete the installation process.


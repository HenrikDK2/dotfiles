# Welcome to my dotfiles

![20230609-162049](https://github.com/HenrikDK2/dotfiles/assets/30632653/f785198b-9339-457e-b58d-5e80eaecf11b)
![20230609-162658](https://github.com/HenrikDK2/dotfiles/assets/30632653/5bf760b1-947b-427d-85a9-d53ae10cf21f)

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

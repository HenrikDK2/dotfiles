# Welcome to my dotfiles

My dotfiles are intended for personal usage, but feel free to make use of them as well. They include all of my configuration files, along with tweaks for system files. I always incorporate these tweaks on my system to enhance responsiveness, gaming performance, and security, when setting up new systems.

**Please note that any usage of my system/configuration files is done at your own risk. I am not liable for any consequences that may arise.**

## Install

### Important considerations before installing

- These configuration/system files have only been tested on a fresh install of [Fedora Cosmic Spin.](https://fedoraproject.org/spins/cosmic)

- Keep in mind that this project is designed specifically for my setup on a **Desktop PC** with **AMD** hardware.

### Installation guide

**Warning!** Executing the following steps will replace your existing files with my configuration files.

1. Navigate to home directory. `/home/<username>`

2. Run the following commands:

   ```
   git init
   git remote add origin https://github.com/HenrikDK2/dotfiles.git
   git fetch --all
   git checkout fedora-cosmic-desktop --force
   ```

3. Now you're almost done! As an user with sudo privileges, execute the installation script `/home/<username>/.my_scripts/init/install.sh` and follow the simple instructions to complete the installation process.

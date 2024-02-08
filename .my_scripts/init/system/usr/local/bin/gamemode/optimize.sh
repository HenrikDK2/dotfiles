#!/bin/sh

# Parameters
# 1. You can use the cmd output to match the specfic process.
# 2. Niceness values range from -20 to 20, lower is higher priority.
# 3. Ionice class, 0 for none, 1 for real time, 2 for best effort, 3 for idle.
# 4. Ionice classdata, range from 0-7, lower is higher. Idle class doesn't allow classdata, so it's ignored.
set_prio () {
    pids=$(pgrep -f "$1")
	nice_value="$2"
    io_class="$3"
    io_classdata="$4"

    if [ -n "$pids" ] && [ -n $nice_value ]; then
        sudo renice -n $nice_value -p $pids

        if [ $io_class ]; then
	        if  [ -z $io_classdata ] || [ $io_class -eq 3 ]; then
	            sudo ionice -c $io_class -p $pids
	        else
	            sudo ionice -c $io_class -n $io_classdata -p $pids
	        fi
        fi
    fi
}

# Improve scheduling in Sway and Gamescope
sudo setcap 'cap_sys_nice=eip' /usr/bin/sway
sudo setcap 'cap_sys_nice=eip' /usr/bin/gamescope

# Set priorities
set_prio "pipewire*" -19
set_prio "wireplumber*" -19
set_prio "systemd-journald" 20 3
set_prio "systemd-timesyncd" 20 3
set_prio "cups" 20 3
set_prio "corectrl" 20 3
set_prio "mako" 20 3
set_prio "polkit-gnome" 20 3
set_prio "waybar" 20 3
set_prio "evolution" 20 3
set_prio "thunderbird" 20 3
set_prio "tidal-hifi" 20 3
set_prio "spotify" 20 3
set_prio "swayidle" 20 3
set_prio "swaybg" 20 3
set_prio "polkit-gnome" 20 3
set_prio "/usr/lib/polkit-1/polkitd" 20 3
set_prio "/usr/bin/dbus-daemon" 20 3
set_prio "bottles" 20 3
set_prio "/opt/Heroic/heroic --" 20 3
set_prio "/usr/bin/lutris" 20 3

# Clear RAM
kill $(pgrep chrome_crashpad)
sudo sh -c 'echo 3 >  /proc/sys/vm/drop_caches'

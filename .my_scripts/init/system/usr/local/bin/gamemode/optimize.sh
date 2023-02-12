#!/bin/sh

# Parameters
# 1. You can use the cmd output to match the specfic process.
# 2. Niceness values range from -20 to 20, lower is higher priority.
# 3. Ionice class, 0 for none, 1 for real time, 2 for best effort, 3 for idle.
# 4. Ionice classdata, range from 0-7, lower is higher. Idle class doesn't allow classdata, so it's ignored.
set_prio () {
    pids=$(pgrep -f "$1")
    if [ -n "$pids" ]; then
        sudo renice -n $2 -p $pids
        if ([ $3 ] && [ -z $4 ]) || [ $3 -eq 3 ]; then
            sudo ionice -c $3 -p $pids
        fi

        if [ $3 -ne 3 ] && [ $4 ]; then
            sudo ionice -c $3 -n $4 -p $pids
        fi
    fi
}

# Set priorities
set_prio "systemd-journald" 20 3
set_prio "systemd-timesyncd" 20 3
set_prio "cups" 20 3
set_prio "corectrl" 20 3
set_prio "mako" 20 3
set_prio "polkit-gnome" 20 3
set_prio "waybar" 20 3
set_prio "evolution" 20 3
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

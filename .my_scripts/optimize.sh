set_prio () {
    pids=$(pgrep -f "$1")
    if [ -n "$pids" ]; then
        renice -n $2 -p $pids
        if [ -n "$3" ]; then
            ionice -c $3 -p $pids
        fi
    fi
}

# Clear RAM
sudo sh -c 'echo 3 >  /proc/sys/vm/drop_caches'  

# ps ax -o pid,ni,cmd
# You can use the cmd output to match the specfic process.
set_prio "corectrl" 20 3
set_prio "mako" 20 3
set_prio "polkit-gnome" 20 3
set_prio "waybar" 20 3
set_prio "evolution" 20 3
set_prio "swayidle" 20 3
set_prio "swaybg" 20 3
set_prio "discord" 10 3
set_prio "steamwebhelper" 10 3
set_prio "Origin" 10 3
set_prio "/opt/Heroic/heroic --" 10 3

# Games - Same priority as gamemode
sleep 30
set_prio "steamapps" -10 1


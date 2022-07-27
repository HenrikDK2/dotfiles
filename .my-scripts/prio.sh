set_prio () {
    pids=$(pgrep -f $1)
    if [ -n "$pids" ]; then
        renice -n $2 -p $pids
        if [ -n "$3" ]; then
            ionice -c $3 -p $pids
        fi
    fi
}

set_prio login.sh 20 idle
set_prio corectrl 20 idle
set_prio mako 20 idle
set_prio polkit-gnome 20 idle
set_prio discord 10 idle
set_prio waybar 20 idle
set_prio .local/share/Steam 10 idle
set_prio Origin 10 idle
set_prio evolution 20 idle
set_prio swayidle 20 idle
set_prio swaybg 20 idle
set_prio pipewire -18

# Steam Games
set_prio steamapps -15 

sleep 30

set_prio () {
    pid=$(pidof $1)
    if [ -n "$pid" ]; then
        renice -n $2 -p $pid
        if [ -n "$3" ]; then
            ionice -c $3 -p $pid
        fi
    fi
}
    
set_prio corectrl 20 idle
set_prio corectrl_helper 20 idle
set_prio mako 20 idle
set_prio polkit-gnome-authentication-agent-1 20 idle
set_prio Discord 10 idle
set_prio steam 20 idle
set_prio steamwebhelper 20 idle
set_prio waybar 20 idle
set_prio evolution 20 idle
set_prio swayidle 20 idle
set_prio swaybg 20 idle
set_prio pipewire -18
set_prio pipewire-pulse -18
sleep 30
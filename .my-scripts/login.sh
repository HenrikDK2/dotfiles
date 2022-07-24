#!/bin/sh

set_prio () {
    pid=$(pidof $1)
    if [ -n "$pid" ]; then
        sudo renice -n $2 -p $pid
        if [ -n "$3" ]; then
            sudo ionice -c $3 -p $pid
        fi
    fi
}

launch () {
    uppercase=${1^}
    if [ -z "$(pidof $1)" ] && [ -z "$(pidof $uppercase)" ]; then
        $1 &
    fi
}

# Sync time
sudo ntpd
sleep 1

# Programs to lauch at login (executable)
launch corectrl
launch discord
launch steam
launch evolution
launch mako
launch waybar 
disown -a

# Reduce priority of this script
pid=$(sh -c 'echo "$PPID"')
renice -n 20 "$pid"
ionice -c idle -p "$pid"

# Priority of processes (name, niceness, ionice class)
while true; do
    set_prio corectrl 20 idle
    set_prio corectrl_helper 20 idle
    set_prio mako 20 idle
    set_prio polkit-gnome-authentication-agent-1 20 idle
    set_prio Discord 10 idle
    set_prio waybar 20 idle
    set_prio evolution 20 idle
    set_prio swayidle 20 idle
    set_prio swaybg 20 idle
    set_prio pipewire -18
    set_prio pipewire-pulse -18
    sleep 30
done
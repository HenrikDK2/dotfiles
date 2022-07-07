#!/bin/sh

sudo ntpd

sleep 1

corectrl & discord & steam & evolution & mako & waybar &

sleep 60

renice -n 20 -p $(pidof corectrl)
ionice -c idle -p $(pidof corectrl)

renice -n 20 -p $(pidof mako)
ionice -c idle -p $(pidof mako)

renice -n 20 -p $(pidof lxqt-policykit-agent)
ionice -c idle -p $(pidof lxqt-policykit-agent)

renice -n 20 -p $(pidof polkit-dumb-agent)
ionice -c idle -p $(pidof polkit-dumb-agent)

renice -n 10 -p $(pidof Discord)
ionice -c idle -p $(pidof Discord)

renice -n 20 -p $(pidof thunderbird)
ionice -c idle -p $(pidof thunderbird)

renice -n 20 -p $(pidof waybar)
ionice -c idle -p $(pidof waybar)

renice -n 20 -p $(pidof evolution)
ionice -c idle -p $(pidof evolution)

renice -n 20 -p $(pidof steam)
ionice -c idle -p $(pidof steam)

renice -n 20 -p $(pidof swayidle)
ionice -c idle -p $(pidof swayidle)

renice -n 20 -p $(pidof swaybg)
ionice -c idle -p $(pidof swaybg)

renice -n -18 -p $(pidof pipewire)
renice -n -18 -p $(pidof pipewire-pulse)

sudo ~/.my-scripts/free-os-cache.sh

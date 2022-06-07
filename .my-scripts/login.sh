#!/bin/sh

sleep 1

corectrl & discord & evolution & mako & waybar &

sleep 30

renice -n 20 -p $(pidof corectrl)
ionice -c 3 -n 7 -p $(pidof corectrl)

renice -n 20 -p $(pidof mako)
ionice -c 3 -n 7 -p $(pidof mako)

renice -n 20 -p $(pidof lxqt-policykit-agent)
ionice -c 3 -n 7 -p $(pidof lxqt-policykit-agent)

renice -n 20 -p $(pidof polkit-dumb-agent)
ionice -c 3 -n 7 -p $(pidof polkit-dumb-agent)

renice -n 20 -p $(pidof discord)
ionice -c 3 -n 7 -p $(pidof discord)

renice -n 20 -p $(pidof thunderbird)
ionice -c 3 -n 7 -p $(pidof thunderbird)

renice -n 20 -p $(pidof waybar)
ionice -c 3 -n 7 -p $(pidof waybar)

renice -n 20 -p $(pidof evolution)
ionice -c 3 -n 7 -p $(pidof evolution)

renice -n 20 -p $(pidof swayidle)
ionice -c 3 -n 7 -p $(pidof swayidle)

renice -n 20 -p $(pidof swaybg)
ionice -c 3 -n 7 -p $(pidof swaybg)

sudo ~/.my-scripts/free-os-cache.sh

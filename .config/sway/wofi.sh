#!/bin/sh

if [ -z "$(pidof wofi)" ]; then
    wofi --show drun -a &
fi
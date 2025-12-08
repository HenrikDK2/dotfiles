#!/bin/bash

if ! pgrep -x rofi; then
    rofi -theme ./styles/theme.rasi -show drun
fi

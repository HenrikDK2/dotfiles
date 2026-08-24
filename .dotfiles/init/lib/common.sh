#!/bin/bash

section() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

clear_screen() {
    local lines
    local offset=${1:-0}
    local clear_lines

    lines=$(tput lines)
    clear_lines=$((lines - offset))

    (( clear_lines < 0 )) && clear_lines=0

    for ((i = 0; i < clear_lines; i++)); do
        echo
    done

    tput cup "$offset" 0
}

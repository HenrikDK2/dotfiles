#!/bin/bash

# Improve response times by avoiding stalls on memory allocations
# A smoother experience at the cost of memory

total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
min_free_kbytes=$((total_memory * 1 / 100)) # 1% of memory

if [ "$min_free_kbytes" -le 4096 ]; then
    min_free_kbytes=4096
fi

sudo sed -i "s/#MEM/$min_free_kbytes/" /etc/tmpfiles.d/performance.conf

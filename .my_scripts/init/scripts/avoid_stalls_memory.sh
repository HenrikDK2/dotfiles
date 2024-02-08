#!/bin/bash

# Improve response times by avoidind stalls on memory allocations
# A smoother experience at the cost of memory

total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_memory_in_gb=$((total_memory / 1024000))  # corrected the calculation

if [ $total_memory_in_gb -ge 24 ]; then
	min_free_kbytes=$((total_memory * 2 / 100)) # 2% of memory
	
	sudo sed -i "s/#MEM/$min_free_kbytes/" /etc/tmpfiles.d/performance.conf
	sudo sed -i "s/#WSF/500/" /etc/tmpfiles.d/performance.conf # 5% of memory
else
	min_free_kbytes=$((total_memory * 1 / 100)) # 1% of memory
	
	sudo sed -i "s/#MEM/$min_free_kbytes/" /etc/tmpfiles.d/performance.conf
	sudo sed -i "s/#WSF/100/" /etc/tmpfiles.d/performance.conf # 1% of memory
fi

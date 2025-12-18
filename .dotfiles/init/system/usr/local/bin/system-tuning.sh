#!/bin/bash

function is_laptop() {
    # Check for presence of a battery device
    if [ -d "/sys/class/power_supply/BAT0" ] || [ -d "/sys/class/power_supply/BAT1" ]; then
        return 0  # true: laptop
    else
        return 1  # false: desktop
    fi
}

function service_exists() {
    systemctl list-unit-files --type=service | grep -q "^$1"
}

# Disable/Enable depending on if a capable bluetooth device is detected
if service_exists "bluetooth.service"; then
    if [ -z "$(ls -A /sys/class/bluetooth/ 2>/dev/null)" ]; then
        systemctl disable --now bluetooth.service
    else
        systemctl enable --now bluetooth.service
    fi
fi

# Disable/Enable depending on if a capable modem device is detected
if service_exists "ModemManager.service"; then
    if \
       ls /dev/cdc-wdm* /dev/ttyUSB* /dev/ttyACM* /dev/wwan* 1>/dev/null 2>&1 \
       || nmcli device 2>/dev/null | grep -q "gsm"
    then
        systemctl enable --now ModemManager.service
    else
        systemctl disable --now ModemManager.service
    fi
fi

# Get total memory in KB
total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# Tiered min_free_kbytes based on total RAM
if [ "$total_memory" -le $((8 * 1024 * 1024)) ]; then        # <= 8  GB
    min_free_kbytes=8192
elif [ "$total_memory" -le $((16 * 1024 * 1024)) ]; then     # <= 16 GB
    min_free_kbytes=16384
elif [ "$total_memory" -le $((32 * 1024 * 1024)) ]; then     # <= 32 GB
    min_free_kbytes=32768
else                                                         # >  32 GB
    min_free_kbytes=65536
fi

# --------------------
# PERFORMANCE TUNING
# --------------------

# Memory Management
sysctl -w vm.swappiness=10                    # Reduce swap usage, keeping more processes in RAM for lower latency.
sysctl -w vm.compaction_proactiveness=0       # Disable aggressive memory compaction to avoid CPU spikes.
sysctl -w vm.min_free_kbytes=$min_free_kbytes # Maintain minimum free memory to prevent out-of-memory stalls.
sysctl -w vm.max_map_count=2147483642         # Allow many memory mappings for large applications and databases.
sysctl -w vm.zone_reclaim_mode=0              # Avoid reclaiming memory from remote NUMA nodes to reduce latency.
sysctl -w vm.page_lock_unfairness=1           # Improve fairness when locking pages, reducing contention.
sysctl -w vm.page-cluster=0                   # Minimize readahead to prevent unnecessary I/O and cache pollution.
sysctl -w vm.dirty_ratio=10                   # Flush dirty pages more aggressively to avoid long writeback pauses.
sysctl -w vm.dirty_background_ratio=5         # Start background flushing earlier to smooth disk I/O.
sysctl -w vm.vfs_cache_pressure=50            # Balance filesystem metadata caching to avoid frequent lookups.
sysctl -w vm.dirty_writeback_centisecs=1500   # Control writeback interval to smooth out disk I/O.
sysctl -w vm.stat_interval=5                  # Less CPU time spent on memory bookkeeping
sysctl -w vm.percpu_pagelist_fraction=0       # Reduce memory allocation overhead
sysctl -w vm.watermark_scale_factor=1         # Minimize memory watermark calculations

# CPU & Scheduler (Low Power Impact)
sysctl -w kernel.sched_min_granularity_ns=1000000      # Fine-tune scheduler granularity for lower latency in interactive tasks.
sysctl -w kernel.sched_autogroup_enabled=0             # Disable autogrouping to prevent latency spikes for single-threaded processes.
sysctl -w kernel.perf_event_paranoid=2                 # Restrict unprivileged access to performance counters to reduce overhead.
sysctl -w kernel.sched_wakeup_granularity_ns=15000000  # Reduce context switching overhead
sysctl -w kernel.sched_migration_cost_ns=5000000       # Improve cache locality
sysctl -w kernel.sched_child_runs_first=0              # Prevent child processes from interrupting
sysctl -w kernel.nmi_watchdog=0                        # Disable NMI watchdog (prevents CPU sleep)
sysctl -w kernel.watchdog=0                            # Disable soft lockup detector
sysctl -w kernel.hung_task_timeout_secs=0              # Disable hung task detection
sysctl -w kernel.numa_balancing=0                      # Disable NUMA balancing (CPU overhead)

# Network Tuning
sysctl -w net.ipv4.tcp_fastopen=3                      # Reduce TCP handshake latency by sending data in the first SYN packet.
sysctl -w net.ipv4.tcp_slow_start_after_idle=0         # Avoid slow-start after idle to maintain throughput for long-lived connections.
sysctl -w net.ipv4.tcp_mtu_probing=1                   # Dynamically discover MTU to prevent fragmentation and improve throughput.
sysctl -w net.core.rmem_max=16777216                   # Increase max socket receive buffer for high-throughput applications.
sysctl -w net.core.wmem_max=16777216                   # Increase max socket send buffer for high-throughput applications.
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"      # Set TCP receive buffer min, default, max for efficient data flow.
sysctl -w net.ipv4.tcp_wmem="4096 87380 16777216"      # Set TCP send buffer min, default, max for efficient data flow.
sysctl -w net.core.netdev_budget=600                   # Improve network interrupt efficiency
sysctl -w net.ipv4.tcp_no_metrics_save=1               # Eliminate periodic TCP housekeeping

# Filesystem Optimizations
sysctl -w fs.inotify.max_user_instances=1024
sysctl -w fs.inotify.max_user_watches=524288
sysctl -w fs.file-max=2097152

# Transparent HugePages (THP)
echo madvise > /sys/kernel/mm/transparent_hugepage/enabled      # Use THP on demand to reduce TLB misses for large memory allocations.
echo advise > /sys/kernel/mm/transparent_hugepage/shmem_enabled # Apply THP to shared memory only when advised to reduce unnecessary CPU overhead.
echo never > /sys/kernel/mm/transparent_hugepage/defrag         # Disable THP defragmentation to avoid CPU stalls during memory allocation.

# Zswap
echo zsmalloc > /sys/module/zswap/parameters/zpool  # Choose efficient memory pool for compressed swap.
echo zstd > /sys/module/zswap/parameters/compressor # Use fast compression algorithm to reduce I/O latency.
echo Y > /sys/module/zswap/parameters/enabled       # Enable compressed swap to reduce pressure on physical memory and disk I/O.

# KSM (Kernel Samepage Merging)
echo 0 > /sys/kernel/mm/ksm/run # Disable KSM to avoid CPU overhead if virtual machines are not used.

if is_laptop; then
    sysctl -w vm.laptop_mode=1                         # Enable laptop mode for better power management
    sysctl -w kernel.timer_migration=1                 # Allow timer migration for better power management

	# Enable TLP service for battery savings when using a laptop
	if ! service_exists "tlp.service"; then
		systemctl enable --now tlp.service
	fi
else
    sysctl -w vm.laptop_mode=0                         # Disable laptop mode
    sysctl -w kernel.timer_migration=0                 # Pin timers to cores (prevents CPU sleep)

 	# Disable TLP service for battery savings when using a dekstop
    if service_exists "tlp.service"; then
    	systemctl disable --now tlp.service
    fi
fi

# --------------------
# SECURITY HARDENING
# --------------------

# Kernel Security
sysctl -w kernel.dmesg_restrict=1               # Restrict dmesg access to root to prevent information leaks.
sysctl -w kernel.ftrace_enabled=0               # Disable kernel function tracing to reduce potential leaks.
sysctl -w kernel.kptr_restrict=2                # Hide kernel pointers from unprivileged users to protect kernel memory layout.
sysctl -w kernel.unprivileged_bpf_disabled=1    # Disable unprivileged BPF programs to reduce attack surface.
sysctl -w kernel.kexec_load_disabled=1          # Prevent unauthorized kernel loading.
sysctl -w kernel.sysrq=0                        # Disable SysRq key sequences to prevent unsafe commands.
sysctl -w fs.suid_dumpable=0                    # Prevent SUID programs from generating core dumps.
sysctl -w kernel.core_pattern="|/dev/null"      # Drop all core dumps to prevent sensitive data leakage.

# Network Security
sysctl -w net.ipv4.tcp_syncookies=1                     # Enable SYN cookies to mitigate SYN flood attacks.
sysctl -w net.ipv4.tcp_timestamps=0                     # Disable TCP timestamps to reduce fingerprinting attack surface.
sysctl -w net.ipv4.tcp_rfc1337=1                        # Handle TIME_WAIT sockets safely to prevent reuse attacks.
sysctl -w net.ipv4.conf.all.rp_filter=1                 # Enable reverse path filtering to prevent IP spoofing.
sysctl -w net.ipv4.conf.default.rp_filter=1
sysctl -w net.ipv4.conf.all.send_redirects=0            # Disable ICMP redirects to prevent MITM attacks.
sysctl -w net.ipv4.conf.all.accept_redirects=0
sysctl -w net.ipv4.conf.default.accept_redirects=0
sysctl -w net.ipv4.conf.all.secure_redirects=0
sysctl -w net.ipv4.conf.default.secure_redirects=0
sysctl -w net.ipv6.conf.all.accept_redirects=0
sysctl -w net.ipv6.conf.default.accept_redirects=0
sysctl -w net.ipv4.conf.all.accept_source_route=0       # Disable source routing to prevent traffic redirection attacks.
sysctl -w net.ipv4.conf.default.accept_source_route=0
sysctl -w net.ipv6.conf.all.accept_source_route=0
sysctl -w net.ipv6.conf.default.accept_source_route=0
sysctl -w net.ipv6.conf.all.accept_ra=0                 # Disable router advertisements to prevent rogue RA attacks.
sysctl -w net.ipv6.conf.default.accept_ra=0
sysctl -w net.ipv4.icmp_echo_ignore_all=1               # Ignore ICMP echo requests to prevent network scanning.
sysctl -w net.ipv6.icmp.echo_ignore_all=1
sysctl -w net.ipv4.tcp_dsack=0                          # Disable duplicate selective ACK to reduce fingerprinting attacks.
sysctl -w net.ipv4.tcp_fack=0                           # Disable FACK to reduce fingerprinting attacks.
sysctl -w net.ipv6.conf.all.disable_ipv6=1              # Disable IPv6 if not needed to reduce attack surface.
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1        # Ignore broadcast pings to prevent amplification attacks.
sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1  # Ignore malformed ICMP packets to prevent network abuse.

###############################
### Future warning to self ####
###############################

# Enable below sysctl network security tweaks to reduce fingerprinting limits
# It reduces download speed on Arma Reforger Workshop, and possibly other services/games 
#sysctl -w net.ipv4.tcp_sack=0 
#sysctl -w net.ipv4.tcp_window_scaling=0
                          
echo ""
echo "=== Optimization Complete ==="
if is_laptop; then
    echo "Laptop Mode: Balanced performance and power efficiency"
else
    echo "Desktop Mode: Maximum performance optimizations applied"
fi

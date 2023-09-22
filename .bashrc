#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1="\[\e[32;1m\]\w\[\e[0m\] \$ "

# Source shared shell config
source ~/.my_scripts/shared_shell_config.sh

# Build directly from ram, if there is 24GB available.
total_free_mem_bytes=$(free -b | awk '/^Mem/ { mem = $4 } /^Swap/ { swap = $4 } END { print mem + swap }')
min_required_mem_bytes=$((24 * 1024 * 1024 * 1024)) # 24GB

if ((total_free_mem_bytes >= min_required_mem_bytes)); then
    export BUILDDIR=/tmp/makepkg
fi
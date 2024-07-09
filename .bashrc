#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1="\[\e[32;1m\]\w\[\e[0m\] \$ "

# Source shared shell config
source ~/.my_scripts/shared_shell_config.sh

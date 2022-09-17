#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1="\[\e[32;1m\]\w\[\e[0m\] \$ "

alias ls='ls --color=auto'
alias dev='npm run dev'
alias build='npm run build'
alias start='npm run start'
alias serve='npm run serve'
alias clean='npm run clean'
alias update='~/.my_scripts/update.sh'
alias install='yay -Syu'
alias remove='yay -Rsn'

export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=sway
export QT_QPA_PLATFORM="wayland;xcb"
export MOZ_ENABLE_WAYLAND=1
export MOZ_WEBRENDER=1
export MICRO_TRUECOLOR=1
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export DXVK_ASYNC=1

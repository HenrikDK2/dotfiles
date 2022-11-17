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
alias uninstall='yay -Rsn'

export EDITOR="micro"
export XDG_CURRENT_DESKTOP=sway
export DESKTOP_SESSION=sway
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM="wayland;xcb"
export MOZ_ENABLE_WAYLAND=1
export MOZ_WEBRENDER=1
export MICRO_TRUECOLOR=1
export RTC_USE_PIPEWIRE=true
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export PATH="$HOME/.local/bin:$PATH"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export DXVK_ASYNC=1
export RADV_FORCE_VRS=2x2
export RADV_DEBUG=novrsflatshading
export RADV_PERFTEST="nggc,sam"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

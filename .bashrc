#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias dev='npm run dev'
alias build='npm run build'
alias start='npm run start'
alias serve='npm run serve'
alias clean='npm run clean'
alias update='~/.my-scripts/update.sh'
alias install='yay -Syu'
alias remove='yay -Rsn'
PS1="\[\e[32;1m\]\w\[\e[0m\] \$ "

if [ -z $DISPLAY ] && [ "$(tty)" = "/dev/tty1" ]; then
    eval $(gnome-keyring-daemon --start)
    export SSH_AUTH_SOCK

	## Env Variables
	export XDG_SESSION_TYPE=wayland
	export XDG_CURRENT_DESKTOP=sway
	export QT_QPA_PLATFORM=wayland
    export MOZ_ENABLE_WAYLAND=1
    export MOZ_WEBRENDER=1
	export MICRO_TRUECOLOR=1
	export XDG_DOWNLOAD_DIR="$HOME/Downloads"
	
	## Execute Window Manager
 	exec sway
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

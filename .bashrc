# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Autostart sway on TTY login
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    nohup sway &>/dev/null &
fi

# Function to get the current Git branch
function parse_git_branch() {
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [ -n "$git_dir" ]; then
        echo "($(git symbolic-ref --short HEAD))"
    fi
}

# Set PS1 to include username in green, hostname in white, path in green, and Git branch if available
export PS1='\[\e[32m\]\u\[\e[37m\]@\h \[\e[32m\]\w\[\e[0m\] $(parse_git_branch)> '

source $HOME/.my_scripts/init/scripts/functions.sh
source /usr/share/blesh/ble.sh --noattach

# Envs
export EDITOR="micro"
export VISUAL="micro"
export DIFFPROG="micro"
export MICRO_CONFIG_HOME=$HOME/.config/micro
export MICRO_TRUECOLOR=1

export RADV_FORCE_VRS="2x2"
export RADV_DEBUG="novrsflatshading"
export AMD_VULKAN_ICD="RADV"
export RADV_PERFTEST="nggc,sam,ngg_streamout"
export VKD3D_CONFIG="dxr11"

#export MOZ_ENABLE_WAYLAND=1 Disabled until copy/paste works again
export MOZ_WEBRENDER=1

export XDG_CURRENT_DESKTOP=sway
export RTC_USE_PIPEWIRE=true
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export OBS_VKCAPTURE=1
export PATH="$HOME/.local/bin:$PATH"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
export FREETYPE_PROPERTIES="hinting=true:hintstyle=hintslight:antialias=rgb:subpixel_rendering=rgb"
export ANDROID_HOME=$HOME/Android/Sdk
export GSK_RENDERER=ngl

# Alias
alias upgraded='grep -i upgraded /var/log/pacman.log'
alias installed='grep -i installed /var/log/pacman.log'
alias audit='~/.my_scripts/audit.sh'
alias dev='npm run dev'
alias build='npm run build'
alias start='npm run start'
alias serve='npm run serve'
alias clean='npm run clean'
alias update='~/.my_scripts/update.sh'
alias install='yay -S'
alias uninstall='yay -Rsn'

[[ ${BLE_VERSION-} ]] && ble-attach
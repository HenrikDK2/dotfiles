# Env Variables
export fish_greeting=""
export fish_color_autosuggestion="595d5e"

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

export MOZ_ENABLE_WAYLAND=1
export MOZ_WEBRENDER=1

export RTC_USE_PIPEWIRE=true
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export OBS_VKCAPTURE=1
export PATH="$HOME/.local/bin:$PATH"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export FREETYPE_PROPERTIES="hinting=true:hintstyle=hintslight:antialias=rgb:subpixel_rendering=rgb"

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

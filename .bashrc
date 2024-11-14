# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Autostart sway on TTY login
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    sway
fi

PS1="\[\e[32;1m\]\w\[\e[0m\] \$ "

# Functions
source $HOME/.my_scripts/init/scripts/functions.sh

# Setup blesh auto-suggestions
source /usr/share/blesh/ble.sh

bleopt edit_magic_expand=history:sabbrev:alias

# Set colors to match the Waybar theme
nord0="#3b4252"       # Background
nord1="#353c4a"       # Darker background
nord2="#e5eaf0"       # Foreground
nord3="#83bfce"       # Accent light teal
nord_safe="#53b500"   # Green (safe)
nord_critical="#bf616a" # Red (critical)
nord_warning="#ebcb8b" # Yellow (warning)

# ble-face color definitions
ble-face argument_error=fg="$nord0",bg="$nord_critical"
ble-face argument_option=fg="$nord3"
ble-face auto_complete=fg=242
ble-face cmdinfo_cd_cdpath=fg="$nord1",bg="$nord_warning"
ble-face command_alias=fg="$nord3"
ble-face command_builtin=fg="$nord_critical"
ble-face command_builtin_dot=fg="$nord_critical",bold
ble-face command_directory=fg=66,underline
ble-face command_file=fg="#81a1c1"
ble-face command_function=fg="$nord3"
ble-face command_jobs=fg="$nord_critical",bold
ble-face command_keyword=fg=109                    # Softer blue
ble-face command_suffix=fg="$nord2",bg="$nord0"
ble-face command_suffix_new=fg="$nord2",bg="$nord_critical"
ble-face disabled=fg=242
ble-face filename_block=fg="$nord_warning",bg="$nord1",underline
ble-face filename_character=fg="$nord2",bg="$nord0",underline
ble-face filename_directory=fg="$nord3",underline
ble-face filename_directory_sticky=fg="$nord2",bg="$nord3",underline
ble-face filename_executable=fg="$nord3",underline
ble-face filename_link=fg="$nord3",underline
ble-face filename_ls_colors=underline
ble-face filename_orphan=fg=16,bg="$nord_warning",underline
ble-face filename_other=underline
ble-face filename_pipe=fg="$nord_safe",bg="$nord0",underline
ble-face filename_setgid=fg="$nord0",bg="$nord_warning",underline
ble-face filename_setuid=fg="$nord0",bg="$nord_warning",underline
ble-face filename_socket=fg="$nord3",bg="$nord0",underline
ble-face filename_url=fg=109,underline           # Blue
ble-face filename_warning=fg="$nord_critical",underline
ble-face menu_desc_default=none
ble-face menu_desc_type=ref:syntax_delimiter
ble-face menu_filter_fixed=bold
ble-face menu_filter_input=fg="$nord3"
ble-face overwrite_mode=fg="$nord1",bg="$nord3"
ble-face prompt_status_line=fg="$nord2",bg="$nord1"
ble-face region=fg="$nord2",bg=66
ble-face region_insert=fg=27,bg=254
ble-face region_match=fg="$nord2",bg=109
ble-face region_target=fg="$nord0",bg="$nord_warning"
ble-face syntax_brace=fg="$nord3",bold
ble-face syntax_command=fg=109                  # Blue
ble-face syntax_comment=fg=242
ble-face syntax_default=none
ble-face syntax_delimiter=bold
ble-face syntax_document=fg=242
ble-face syntax_document_begin=fg=242,bold
ble-face syntax_quotation=fg=#ebcb8b,bold
ble-face syntax_quoted=fg=#ebcb8b
ble-face syntax_error=fg="$nord_critical"
ble-face syntax_escape=fg="$nord3"
ble-face syntax_expr=fg="$nord3"
ble-face syntax_function_name=fg="$nord3",bold
ble-face syntax_glob=fg="$nord_warning",bold
ble-face syntax_history_expansion=fg="$nord2",bg=109
ble-face syntax_param_expansion=fg=109          # Light blue
ble-face syntax_quoted=fg=#ebcb8b
ble-face syntax_quotation=fg=#ebcb8b,bold
ble-face syntax_tilde=fg=109,bold               # Light blue
ble-face syntax_varname=fg=109                  # Light blue
ble-face varname_array=fg=109,bold
ble-face varname_empty=fg=31
ble-face varname_export=fg="$nord_warning",bold
ble-face varname_expr=fg="$nord3",bold
ble-face varname_hash=fg="$nord3",bold
ble-face varname_new=fg=34
ble-face varname_number=fg=64
ble-face varname_readonly=fg="$nord_warning"
ble-face varname_transform=fg=109,bold
ble-face varname_unset=fg=245
ble-face vbell=reverse
ble-face vbell_erase=bg=252
ble-face vbell_flash=fg="$nord_safe",reverse

ble-face syntax_default=fg="$nord3"

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

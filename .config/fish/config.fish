# Env Variables
set fish_greeting
set -x EDITOR micro
set -x VISUAL micro
set -x DIFFPROG micro
set -x MOZ_ENABLE_WAYLAND 1
set -x MOZ_WEBRENDER 1
set -x MICRO_TRUECOLOR 1
set -x RTC_USE_PIPEWIRE true
set -x MICRO_CONFIG_HOME "$HOME/.config/micro"
set -x XDG_DOWNLOAD_DIR "$HOME/Downloads"
set -x OBS_VKCAPTURE 1
set -x PATH "$HOME/.local/bin:$PATH"
set -x DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1
set -x RADV_FORCE_VRS 2x2
set -x RADV_DEBUG novrsflatshading
set -x AMD_VULKAN_ICD RADV
set -x RADV_PERFTEST "nggc,sam,ngg_streamout"
set -g fish_color_autosuggestion 595d5e

# Alias
alias upgraded 'grep -i upgraded /var/log/pacman.log'
alias installed 'grep -i installed /var/log/pacman.log'
alias audit '~/.my_scripts/audit.sh'
alias dev 'npm run dev'
alias build 'npm run build'
alias start 'npm run start'
alias serve 'npm run serve'
alias clean 'npm run clean'
alias update '~/.my_scripts/update.sh'
alias install 'yay -Syu'
alias uninstall 'yay -Rsn'

if status is-interactive
    if type -q fisher;
        if not test -e ~/.config/fish/functions/nvm.fish; 
            fisher install jorgebucaran/nvm.fish
        end
    
         # Install nvm
        if not test -e ~/.config/fish/functions/_autopair_tab.fish; 
            fisher install fisher install jorgebucaran/autopair.fish
        end

        clear
    end
   

    # On login
    if test -z "$DISPLAY"; and test (tty) = /dev/tty1
        sway
    end
end

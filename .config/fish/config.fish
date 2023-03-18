# Env Variables
set fish_greeting
set -x EDITOR micro
set -x VISUAL micro
set -x XDG_CURRENT_DESKTOP sway
set -x DESKTOP_SESSION sway
set -x XDG_SESSION_TYPE wayland
set -x QT_QPA_PLATFORM "wayland;xcb"
set -x QT_WAYLAND_FORCE_DPI "physical"
set -x QT_WAYLAND_DISABLE_WINDOWDECORATION 1
set -x MOZ_ENABLE_WAYLAND 1
set -x MOZ_WEBRENDER 1
set -x MICRO_TRUECOLOR 1
set -x RTC_USE_PIPEWIRE true
set -x MICRO_CONFIG_HOME "$HOME/.config/micro"
set -x XDG_DOWNLOAD_DIR "$HOME/Downloads"
set -x OBS_VKCAPTURE 1
set -x PATH "$HOME/.local/bin:$PATH"
set -x DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1
set -x DXVK_ASYNC 1
set -x RADV_FORCE_VRS 2x2
set -x RADV_DEBUG novrsflatshading
set -x AMD_VULKAN_ICD RADV
set -x RADV_PERFTEST "nggc,sam,ngg_streamout"

# Alias
alias audit "echo -e '\n\e[1mChecking for failed services\e[0m \n'; systemctl --failed; echo -e '\n----------------------------------------------\n\n\e[1mChecking for high priority errors in systemd journal\e[0m \n'; journalctl -p 3 -b"
alias dev 'npm run dev'
alias build 'npm run build'
alias start 'npm run start'
alias serve 'npm run serve'
alias clean 'npm run clean'
alias update '~/.my_scripts/update.sh'
alias install 'yay -Syu'
alias uninstall 'yay -Rsn'


if status is-interactive
    # Install nvm
    if type -q fisher; and not test -e ~/.config/fish/functions/nvm.fish
        fisher install jorgebucaran/nvm.fish
        clear
    end

    # On login
    if test -z "$DISPLAY"; and test (tty) = /dev/tty1
        sway
    end
end

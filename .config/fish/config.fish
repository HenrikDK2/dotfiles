# Env Variables
set -x XDG_SESSION_TYPE wayland
set -x XDG_CURRENT_DESKTOP sway
set -x QT_QPA_PLATFORM "wayland;xcb"
set -x MOZ_ENABLE_WAYLAND 1
set -x MOZ_WEBRENDER 1
set -x MICRO_TRUECOLOR 1
set -x XDG_DOWNLOAD_DIR "$HOME/Downloads"
set -x PATH "$HOME/.local/bin:$PATH"
set -x DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1
set -x DXVK_ASYNC 1

# Alias
alias dev 'npm run dev'
alias build 'npm run build'
alias start 'npm run start'
alias serve 'npm run serve'
alias clean 'npm run clean'
alias update '~/.my-scripts/update.sh'
alias install 'yay -Syu'
alias uninstall 'yay -Rsn'

# Execute WM
if status is-interactive;
    if test -z "$DISPLAY"; and test (tty) = /dev/tty1;
     	exec sway
    end
end

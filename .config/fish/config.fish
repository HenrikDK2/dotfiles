##################
### AUTO START ###
##################

if status is-login; and test -z "$DISPLAY"; and test (tty) = "/dev/tty1"
    # Create log directory if it doesn't exist
    mkdir -p ~/.cache/hyprland
    set LOG_FILE ~/.cache/hyprland/startup.log
    
    # Reset the log file on each boot
    truncate -s 0 $LOG_FILE
    
    # Run Hyprland and log output
    exec hyprland &> $LOG_FILE
end

####################
### GIT FUNCTION ###
####################

function git_hard_reset_to_commit
    clear

    # Check if Git is installed
    if not command -v git &> /dev/null
        echo "Git is not installed. Please install Git and try again."
        return 1
    end

    echo -e "Recent commits:\n"
    git --no-pager log --pretty=format:"%ad | %h | %s" --abbrev-commit -n 20 --date=format:"%Y-%m-%d %H:%M"
    
    echo -e "\n"
    read -P "Enter the commit hash to reset to: " commit_hash

    if not git rev-parse "$commit_hash" >/dev/null 2>&1
        echo "❌ Invalid commit hash."
        return 1
    end

    echo "⚠️ This will reset your local branch to $commit_hash and force-push to origin. Continue? (y/N)"
    read -r confirm
    if test "$confirm" != "y"; and test "$confirm" != "Y"
        echo "❌ Aborted."
        return 1
    end

    git reset --hard "$commit_hash"; or return 1

    set branch_name (git rev-parse --abbrev-ref HEAD)
    git push origin "$branch_name" --force
end

function push_commit
    set status_output (git status)
    set diff_output (git diff)
    
    if test -z "$diff_output"; and not string match -q "*Changes to be committed*" $status_output
        git status
        return 1
    end

    if string match -q "*no changes added to commit*" $status_output
        git -C (git rev-parse --show-toplevel) add .
    end
    
    read -P "Commit message: " msg
    git commit -m "$msg"
    git push
    
    set cols (stty size | awk '{print $2}')
    printf '%*s\n' $cols '' | tr ' ' '-'
    
    git status
end

#############################
### ENVIRONMENT VARIABLES ###
#############################

set -gx EDITOR "micro"
set -gx VISUAL "micro"
set -gx DIFFPROG "micro"
set -gx SYSTEMD_EDITOR "micro"

set -gx MICRO_CONFIG_HOME $HOME/.config/micro
set -gx MICRO_TRUECOLOR 1

set -gx MOZ_ENABLE_WAYLAND 1
set -gx MOZ_WEBRENDER 1

set -gx PROTON_FORCE_LARGE_ADDRESS_AWARE 1
set -gx LD_PRELOAD ""

set -gx AMD_VULKAN_ICD "RADV"
set -gx XDG_DOWNLOAD_DIR "$HOME/Downloads"
set -gx ANDROID_HOME $HOME/Android/Sdk
set -gx OBS_VKCAPTURE 1
set -gx DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
set -gx FREETYPE_PROPERTIES "hinting=true:hintstyle=hintslight:antialias=rgb:subpixel_rendering=rgb"
set -U fish_greeting

# Add ~/.local/bin to PATH
fish_add_path -p $HOME/.local/bin

###############
### ALIASES ###
###############

alias upgraded='grep -i upgraded /var/log/pacman.log'
alias installed='grep -i installed /var/log/pacman.log'
alias audit='~/.dotfiles/scripts/audit.sh -q'
alias build='npm run build'
alias start='npm run start || npm run dev'
alias push='push_commit'
alias reset='git_hard_reset_to_commit'

############
### MISC ###
############

# FastFetch - Runs if there is only one window in the workspace
if status is-interactive; and pgrep -x "hyprland" >/dev/null; and test (tput cols) -ge 90; and test (tput lines) -ge 25
    set current_workspace (hyprctl activeworkspace -j | jq -r '.id')
    set window_count (hyprctl clients -j | jq --arg ws "$current_workspace" 'map(select(.workspace.id == ($ws | tonumber))) | length')

    if test $window_count -eq 1
        fastfetch
        echo
    end
end

# Fish uses its own key bindings system
# These replace the bash bind commands for Ctrl+Left/Right
if status is-interactive
    bind \e\[1\;5C forward-word
    bind \e\[1\;5D backward-word
end

# Steam launch options comment
# file.exe - Path to a custom .exe file, relative to the game's .exe directory.
# cmd=(gamescope -w 2560 -h 1440 -- gamemoderun %command%); cmd[-1]=file.exe; "${cmd[@]}"

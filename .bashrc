# If not running interactively, don't do anything
[[ $- != *i* ]] && return

##################
### AUTO START ###
##################

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    # Create log directory if it doesn't exist
    mkdir -p ~/.cache/hyprland
    LOG_FILE=~/.cache/hyprland/startup.log
    
    # Reset the log file on each boot
    > "$LOG_FILE" 
    
    # Run Hyprland and log output
    exec hyprland &> "$LOG_FILE"
fi

####################
### GIT FUNCTION ###
####################

git_hard_reset_to_commit() {
	clear

	# Check if Git is installed
	if ! command -v git &> /dev/null; then
	    echo "Git is not installed. Please install Git and try again."
	    return 1
	fi

	echo -e "Recent commits:\n"
	git --no-pager log --pretty=format:"%ad | %h | %s" --abbrev-commit -n 20 --date=format:"%Y-%m-%d %H:%M"
	
	echo -e "\n"
	read -p "Enter the commit hash to reset to: " commit_hash

	if ! git rev-parse "$commit_hash" >/dev/null 2>&1; then
	  echo "❌ Invalid commit hash."
	  return 1
	fi

	echo "⚠️ This will reset your local branch to $commit_hash and force-push to origin. Continue? (y/N)"
	read -r confirm
	if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
	  echo "❌ Aborted."
	  return 1
	fi

	git reset --hard "$commit_hash" || return 1

	branch_name=$(git rev-parse --abbrev-ref HEAD)
	git push origin "$branch_name" --force
}

push_commit() {
	local status=$(git status)
	
	if [[ "$(git diff)" == "" ]] && [[ ! "$status" =~ "Changes to be committed" ]]; then
		git status
		return 1
	fi

	if [[ "$status" =~ "no changes added to commit" ]]; then
		git add .
	fi 
	
    read -p "Commit message: " msg
    git commit -m "$msg"
	git push
	
	cols=$(stty size | awk '{print $2}')
	printf '%*s\n' "$cols" '' | tr ' ' '-'
	
	git status
}

#############################
### ENVIRONMENT VARIABLES ###
#############################

parse_git_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/(/;s/$/)/'; }
export PS1='\[\e[32m\]\u\[\e[37m\]@\h \[\e[32m\]\w\[\e[0m\] $(parse_git_branch)> '

export EDITOR="micro"
export VISUAL="micro"
export DIFFPROG="micro"
export SYSTEMD_EDITOR="micro"

export MICRO_CONFIG_HOME=$HOME/.config/micro
export MICRO_TRUECOLOR=1

export MOZ_ENABLE_WAYLAND=1
export MOZ_WEBRENDER=1

export PROTON_FORCE_LARGE_ADDRESS_AWARE=1 # Allows 32-bit applications to access up to 4 GB of virtual memory.
export LD_PRELOAD="" # Fixes issues with games suttering after 30 minutes (https://github.com/ValveSoftware/steam-for-linux/issues/11446)

export AMD_VULKAN_ICD="RADV"
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export PATH="$HOME/.local/bin:$PATH"
export ANDROID_HOME=$HOME/Android/Sdk
export OBS_VKCAPTURE=1
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
export FREETYPE_PROPERTIES="hinting=true:hintstyle=hintslight:antialias=rgb:subpixel_rendering=rgb"

###############
### ALIASES ###
###############

# Aliases (all defined at once)
alias upgraded='grep -i upgraded /var/log/pacman.log'
alias installed='grep -i installed /var/log/pacman.log'
alias audit='~/.my_scripts/scripts/audit.sh -q'
alias dev='npm run dev'
alias build='npm run build'
alias start='npm run start'
alias serve='npm run serve'
alias clean='npm run clean'
alias push='push_commit'
alias reset="git_hard_reset_to_commit"
alias install='yay -S'
alias uninstall='yay -Rsn'

############
### MISC ###
############

# FastFetch - Runs if there is only one window in the workspace
if pgrep -x "hyprland" >/dev/null && (( $(tput cols) >= 90 && $(tput lines) >= 25 )); then
    current_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
    window_count=$(hyprctl clients -j | jq --arg ws "$current_workspace" 'map(select(.workspace.id == ($ws | tonumber))) | length')

    if (( window_count == 1 )); then
        fastfetch
        echo
    fi
fi

# Source external files (moved down to load essential bash config first)
[ -f "/usr/share/blesh/ble.sh" ] && source "/usr/share/blesh/ble.sh" --noattach

# Disable bracketed paste mode
bind 'set enable-bracketed-paste off' &>/dev/null
declare -- _ble_bash="50299"

# ble-sh attach only if it was loaded successfully
[[ ${BLE_VERSION-} ]] && ble-attach

# Ctrl+Right → forward-word
bind '"\e[1;5C": forward-word'

# Ctrl+Left → backward-word
bind '"\e[1;5D": backward-word'


# Steam launch options comment
# file.exe - Path to a custom .exe file, relative to the game's .exe directory.
# cmd=(gamescope -w 2560 -h 1440 -- gamemoderun %command%); cmd[-1]=file.exe; "${cmd[@]}"

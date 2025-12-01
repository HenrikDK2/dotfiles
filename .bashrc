# .bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Blinking bar cursor
printf '\e[5 q'

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi

parse_git_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/(/;s/$/)/'; }

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
		(cd $(git rev-parse --show-toplevel) && git add .)
	fi 
	
    read -p "Commit message: " msg
    git commit -m "$msg"
	git push
	
	cols=$(stty size | awk '{print $2}')
	printf '%*s\n' "$cols" '' | tr ' ' '-'
	
	git status
}

# Variables
export PS1='\[\e[32m\]\u\[\e[37m\]@\h \[\e[32m\]\w\[\e[0m\] $(parse_git_branch)> '
export PATH

export EDITOR="micro"
export VISUAL="micro"
export DIFFPROG="micro"
export SYSTEMD_EDITOR="micro"

export MICRO_CONFIG_HOME=$HOME/.config/micro
export MICRO_TRUECOLOR=1

export MOZ_ENABLE_WAYLAND=1
export MOZ_WEBRENDER=1

export AMD_VULKAN_ICD="RADV"
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export OBS_VKCAPTURE=1
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
export FREETYPE_PROPERTIES="hinting=true:hintstyle=hintslight:antialias=rgb:subpixel_rendering=rgb"

# Aliases (all defined at once)
alias push='push_commit'
alias audit='$HOME/.my_scripts/scripts/audit.sh'
alias reset="git_hard_reset_to_commit"
alias install='sudo dnf install -y'
alias uninstall='sudo dnf remove -y'

if [ ! -f $HOME/.local/share/blesh/ble.sh ]; then
	curl -L https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
	bash ble-nightly/ble.sh --install ~/.local/share
fi

source -- $HOME/.local/share/blesh/ble.sh

# Disable bracketed paste mode
bind 'set enable-bracketed-paste off' &>/dev/null
declare -- _ble_bash="50299"

# Steam launch options comment
# file.exe - Path to a custom .exe file, relative to the game's .exe directory.
# cmd=(gamescope -w 2560 -h 1440 -- gamemoderun %command%); cmd[-1]=file.exe; "${cmd[@]}"

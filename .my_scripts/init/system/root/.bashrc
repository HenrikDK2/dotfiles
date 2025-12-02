# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

parse_git_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/(/;s/$/)/'
}

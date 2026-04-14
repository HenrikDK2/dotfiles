#!/usr/bin/env bash

# Github
version=$(
  curl -sf "https://api.github.com/repos/roddhjav/apparmor.d/releases/latest" \
    | jq -r '.tag_name // empty' \
    | sed 's/^v//'
)

# AUR
if [[ -z "$version" ]]; then
  version=$(
    curl -sf "https://aur.archlinux.org/rpc/v5/info?arg[]=apparmor.d" \
      | jq -r '.results[0].Version // empty'
  )
fi

echo "$version"


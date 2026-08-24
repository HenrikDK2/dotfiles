#!/usr/bin/env bash

# GitHub
version=$(
  curl -sf "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" \
    | jq -r '.tag_name // empty' \
    | sed 's/ //g; s/-/_/g'
)

# AUR fallback
if [[ -z "$version" ]]; then
  version=$(
    curl -sf "https://aur.archlinux.org/rpc/v5/info?arg[]=proton-ge-custom-bin" \
      | jq -r '.results[0].Version // empty'
  )
fi

echo "$version"

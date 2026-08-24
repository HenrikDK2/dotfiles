#!/usr/bin/env bash

# GitHub
version=$(
  curl -sf "https://api.github.com/repos/PancakeTAS/lsfg-vk/releases/latest" \
    | jq -r '.tag_name // empty' \
    | sed 's/^v//'
)

# AUR fallback
if [[ -z "$version" ]]; then
  version=$(
    curl -sf "https://aur.archlinux.org/rpc/v5/info?arg[]=lsfg-vk" \
      | jq -r '.results[0].Version // empty'
  )
fi

echo "$version"

#!/usr/bin/env bash

# GitHub
version=$(
  curl -sf "https://api.github.com/repos/Korthos-Software/low_latency_layer/releases/latest" \
    | jq -r '.tag_name // empty' \
    | sed 's/^v//; s/-Mavy//g'
)

# AUR fallback
if [[ -z "$version" ]]; then
  version=$(
    curl -sf "https://aur.archlinux.org/rpc/v5/info?arg[]=vulkan-low-latency-layer" \
      | jq -r '.results[0].Version // empty'
  )
fi

echo "$version"

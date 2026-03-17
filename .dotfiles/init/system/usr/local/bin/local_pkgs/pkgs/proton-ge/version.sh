#!/usr/bin/env bash

curl -sf "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" \
  | jq -r '.tag_name | gsub(" "; "") | gsub("-"; "_")'

#!/usr/bin/env bash

curl -sf "https://api.github.com/repos/PancakeTAS/lsfg-vk/releases/latest" \
  | jq -r '.tag_name | gsub("^v"; "")'

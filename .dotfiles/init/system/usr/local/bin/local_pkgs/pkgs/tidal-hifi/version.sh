#!/usr/bin/env bash

# Github
curl -sf "https://api.github.com/repos/Mastermindzh/tidal-hifi/releases/latest" \
  | jq -r '.tag_name' \
  | sed 's/^v//; s/-Mavy//g'


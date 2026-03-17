#!/usr/bin/env bash

curl -sf "https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest" \
  | jq -r '.tag_name | gsub("^v"; "")'

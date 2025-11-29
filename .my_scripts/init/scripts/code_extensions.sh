#!/bin/sh

# List of vscode plugins
plugins=(
    "redhat.vscode-yaml"
    "aaron-bond.better-comments"
    "llvm-vs-code-extensions.vscode-clangd"
    "mikestead.dotenv"
    "stylelint.vscode-stylelint"
    "ritwickdey.LiveServer"
    "pkief.material-icon-theme"
    "formulahendry.code-runner"
    "styled-components.vscode-styled-components"
    "formulahendry.auto-rename-tag"
    "formulahendry.auto-close-tag"
    "esbenp.prettier-vscode"
    "eamodio.gitlens"
    "dbaeumer.vscode-eslint"
    "bmalehorn.vscode-fish"
)

# Fix for code failing to get right directory
cd $HOME

# Get the list of installed extensions
installed_plugins=$(code --list-extensions)

# Loop through plugins and install only if not already installed
for plugin in "${plugins[@]}"; do
    if echo "$installed_plugins" | grep -q "$plugin"; then
        echo "$plugin is already installed"
    else
        code --install-extension "$plugin" --force
    fi
done

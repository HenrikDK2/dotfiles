#!/bin/bash

if command -v code > /dev/null 2>&1; then
    plugins=(
        "redhat.vscode-yaml"
        "aaron-bond.better-comments"
        "llvm-vs-code-extensions.vscode-clangd"
        "mikestead.dotenv"
        "stylelint.vscode-stylelint"
        "ritwickdey.liveserver"
        "pkief.material-icon-theme"
        "formulahendry.code-runner"
        "styled-components.vscode-styled-components"
        "formulahendry.auto-rename-tag"
        "cipchk.cssrem"
        "formulahendry.auto-close-tag"
        "esbenp.prettier-vscode"
        "eamodio.gitlens"
        "dbaeumer.vscode-eslint"
        "bmalehorn.vscode-fish"
    )

    # Get the list of installed extensions
    installed_plugins=$(code --list-extensions)

    # Loop through plugins and install only if not already installed
    for plugin in "${plugins[@]}"; do
        if ! echo "$installed_plugins" | grep -q "$plugin"; then
            echo "Installing $plugin..."
            code --install-extension "$plugin"
        fi
    done
fi

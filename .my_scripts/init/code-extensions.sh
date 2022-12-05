#!/bin/sh

# Install vscode plugins
plugins=(
    "redhat.vscode-yaml"
    "llvm-vs-code-extensions.vscode-clangd"
    "mikestead.dotenv"
    "stylelint.vscode-stylelint"
    "ritwickdey.LiveServer"
    "pkief.material-icon-theme"
    "formulahendry.code-runner"
    "jpoissonnier.vscode-styled-components"
    "formulahendry.auto-rename-tag"
    "formulahendry.auto-close-tag"
    "esbenp.prettier-vscode"
    "eamodio.gitlens"
    "dbaeumer.vscode-eslint"
    "bmalehorn.vscode-fish"
    )

for plugin in "${plugins[@]}"; do
    code --install-extension $plugin
done

clear

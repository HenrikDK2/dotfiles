#!/bin/sh

# Install vscode plugins
plugins=(
    "redhat.vscode-yaml"
    "aaron-bond.better-comments"
    "VisualStudioExptTeam.vscodeintellicode"
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
    "MariusAlchimavicius.json-to-ts"
    "bmalehorn.vscode-fish"
    )

for plugin in "${plugins[@]}"; do
    code --install-extension $plugin
done

clear

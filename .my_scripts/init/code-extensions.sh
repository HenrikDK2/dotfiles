#!/bin/sh

# Install vscode plugins
plugins=("redhat.vscode-yaml" "GraphQL.vscode-graphql" "wix.vscode-import-cost" "mikestead.dotenv" "stylelint.vscode-stylelint" "ritwickdey.LiveServer" "pkief.material-icon-theme" "formulahendry.code-runner" "jpoissonnier.vscode-styled-components" "formulahendry.auto-rename-tag" "formulahendry.auto-close-tag" "esbenp.prettier-vscode" "eamodio.gitlens" "dsznajder.es7-react-js-snippets" "dbaeumer.vscode-eslint" "bmalehorn.vscode-fish")

for plugin in "${plugins[@]}"
do
    code --install-extension $plugin
done

clear
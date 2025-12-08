#!/bin/bash

# Only copies if config folders are missing
if [ ! -d "$HOME/.config/qBittorrent" ]; then
    cp -rf $SCRIPT_DIR/user/qBittorrent $HOME/.config
    sed -i "s|/home/henrik|$HOME|g" $HOME/.config/qBittorrent/qBittorrent.conf
fi


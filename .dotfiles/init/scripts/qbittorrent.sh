#!/bin/bash

# Only copies if config folders are missing
if [ ! -f "$HOME/.config/qBittorrent/blue.qbtheme" ]; then
    cp -rf $SCRIPT_DIR/user/qBittorrent $HOME/.config/qBittorrent
    sed -i "s|/home/henrik|$HOME|g" $HOME/.config/qBittorrent/qBittorrent.conf
fi


#!/bin/bash

# The script will copy the config settings only if the Heroic folder is empty.
cp -rf $DIR/user/qBittorrent $HOME/.config
sed -i "s/henrik/$USER/" $HOME/.config/qBittorrent/qBittorrent.conf
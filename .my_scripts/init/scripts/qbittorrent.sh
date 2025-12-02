#!/bin/bash

# The script will copy the config settings only if the qBitorrent folder is empty.
if [ ! -d $HOME/.config/qBittorrent ]; then
	echo "PATH $DIR/user/qBittorrent"
	cp -rf $DIR/user/qBittorrent $HOME/.config
	sed -i "s/henrik/$USER/" $HOME/.config/qBittorrent/qBittorrent.conf
fi

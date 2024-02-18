#!/bin/bash

if ! grep -qF "[cachyos]" "/etc/pacman.conf"; then
	curl -o $HOME/cachyos-repo.tar.xz https://mirror.cachyos.org/cachyos-repo.tar.xz
	tar xvf $HOME/cachyos-repo.tar.xz
	cd $HOME/cachyos-repo
	sudo ./cachyos-repo.sh
	rm -rf $HOME/*cachyos-repo*
fi

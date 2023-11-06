#!/bin/bash

wget https://mirror.cachyos.org/cachyos-repo.tar.xz -P $HOME
tar xvf $HOME/cachyos-repo.tar.xz
cd $HOME/cachyos-repo
sudo ./cachyos-repo.sh
rm -rf cachyos-repo*

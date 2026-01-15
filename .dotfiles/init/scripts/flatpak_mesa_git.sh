#!/bin/bash

flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
RUNTIME_BRANCH="$(flatpak info --show-runtime com.valvesoftware.Steam//stable | cut -d/ -f3)"
flatpak install -y flathub-beta org.freedesktop.Platform.{GL,GL32}.mesa-git//$RUNTIME_BRANCH
flatpak override --env=FLATPAK_GL_DRIVERS=mesa-git

include disable-common.inc
include disable-devel.inc
include disable-interpreters.inc
include disable-programs.inc
include landlock-common.inc

read-only ${HOME}
read-only /

whitelist ${HOME}/.config/lsfg-vk
whitelist ${HOME}/.cache
whitelist ${HOME}/.local/share/Steam/steamapps/common/Lossless Scaling

net none
keep-dev-ntsync
caps.drop all
novideo
netfilter
nodvd
nogroups
nonewprivs
noroot
notv

disable-mnt
private-cache
private-etc fonts
private-tmp

dbus-system none

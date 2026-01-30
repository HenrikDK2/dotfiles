# noblacklist / allow.inc files always on top
include allow-java.inc # blacklisted by disable-devel.inc
include allow-python2.inc # blacklisted by disable-interpreters.inc
include allow-python3.inc # blacklisted by disable-interpreters.inc

include disable-common.inc
include disable-devel.inc
include disable-interpreters.inc
include disable-programs.inc

include whitelist-common.inc
include whitelist-var-common.inc

whitelist ${HOME}/.cache
whitelist ${HOME}/Games
whitelist ${HOME}/Downloads

whitelist ${HOME}/.config/pulse
whitelist ${HOME}/.config/MangoHud
whitelist ${HOME}/.config/heroic
whitelist ${HOME}/.config/lsfg-vk
whitelist ${HOME}/.local/state/Heroic
whitelist ${HOME}/.local/share/umu

protocol unix,inet,inet6,netlink

keep-dev-ntsync
caps.drop all
novideo
netfilter
nodvd
nogroups
nonewprivs
noroot
notv

private-dev
private-etc @games,@tls-ca,@x11,bumblebee,dbus-1,host.conf,lsb-release,mime.types,os-release,services
private-tmp

seccomp.32 !process_vm_readv
seccomp !chroot,!mount,!name_to_handle_at,!pivot_root,!process_vm_readv,!ptrace,!umount2

# noblacklist / allow.inc files always on top
noblacklist ${HOME}/.mozilla
noblacklist ${HOME}/cache/.mozilla
noblacklist ${HOME}/.local/share/pki
noblacklist ${HOME}/.mailcap
noblacklist ${HOME}/.pki

# noexec in HOME and RUNUSER breaks DRM binaries.
?BROWSER_ALLOW_DRM: ignore noexec ${HOME}
?BROWSER_ALLOW_DRM: ignore noexec ${RUNUSER}

include disable-common.inc
include disable-devel.inc
include disable-interpreters.inc
include disable-programs.inc

whitelist ${DOWNLOADS}
whitelist ${HOME}/.mozilla
whitelist ${HOME}/Documents/*.json
whitelist ${HOME}/.local/share/pki
whitelist ${HOME}/.mailcap
whitelist ${HOME}/.pki
whitelist /usr/share/doc
whitelist /usr/share/gtk-doc/html
whitelist /usr/share/mozilla
whitelist /usr/share/webext
include whitelist-common.inc
include whitelist-run-common.inc
include whitelist-runuser-common.inc
include whitelist-usr-share-common.inc
include whitelist-var-common.inc

private-tmp
disable-mnt

apparmor
apparmor-replace
caps.drop all
netfilter
nodvd
nogroups
nonewprivs
noinput
notv
protocol unix,inet,inet6,netlink
seccomp !chroot

dbus-system none
dbus-user filter

dbus-user.own org.mozilla.*
dbus-user.own org.mpris.MediaPlayer2.firefox.*
dbus-user.talk org.freedesktop.portal.Desktop
dbus-user.talk org.Nemo
dbus-user.talk org.freedesktop.FileManager1
dbus-user.talk org.freedesktop.UPower
dbus-user.talk org.freedesktop.Notifications

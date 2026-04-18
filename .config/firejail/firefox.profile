whitelist ${DOWNLOADS}
whitelist ${HOME}/.mozilla
whitelist ${HOME}/.config/mozilla
whitelist ${HOME}/Documents
whitelist ${HOME}/.local/share/pki
whitelist ${HOME}/.mailcap
whitelist ${HOME}/.pki

dbus-system none
dbus-user filter

dbus-user.own org.mpris.MediaPlayer2.firefox.*
dbus-user.talk org.freedesktop.portal.Desktop
dbus-user.talk org.Nemo
dbus-user.talk org.freedesktop.FileManager1
dbus-user.talk org.freedesktop.UPower
dbus-user.talk org.freedesktop.Notifications

# Allow Steam from disable-programs.inc
noblacklist ${HOME}/.Steam
noblacklist ${HOME}/.Steampath
noblacklist ${HOME}/.Steampid
noblacklist ${HOME}/.cache/steam
noblacklist ${HOME}/.config/steam
noblacklist ${HOME}/.local/share/Steam
noblacklist ${HOME}/.local/share/steam
noblacklist ${HOME}/.steam
noblacklist ${HOME}/.steampath
noblacklist ${HOME}/.steampid
noblacklist ${RUNUSER}/steam

include disable-common.inc
include disable-programs.inc

whitelist ${HOME}/.cache
whitelist ${HOME}/Games
whitelist ${HOME}/Downloads

whitelist ${HOME}/.config/heroic
whitelist ${HOME}/.config/pulse
whitelist ${HOME}/.config/MangoHud
whitelist ${HOME}/.config/lsfg-vk

whitelist ${HOME}/.local/state/Heroic
whitelist ${HOME}/.local/share/umu
whitelist ${HOME}/.local/share/vulkan

apparmor
nonewprivs
noroot

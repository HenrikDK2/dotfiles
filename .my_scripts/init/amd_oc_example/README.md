## Install

1. Copy amd-overclock.service to /etc/systemd/system/
2. Modify oc.sh and copy to /usr/local/bin
3. Enable amd-overclock.service (sudo systemctl enable amd-overclock.service)

## Fans

The fans directory is for adjusting fan speed when gamemode is active.

1. Modify fans.sh inside start.d to your liking
2. Copy both folders inside the fans directory to /usr/local/bin/gamemode/

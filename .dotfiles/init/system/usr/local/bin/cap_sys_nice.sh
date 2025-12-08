#!/bin/bash

set -e

[[ -f /usr/bin/sway ]] && setcap 'CAP_SYS_NICE=eip' /usr/bin/sway
[[ -f /usr/bin/gamescope ]] && setcap 'CAP_SYS_NICE=eip' /usr/bin/gamescope

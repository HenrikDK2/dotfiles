#!/bin/sh

renice -n 20 $$
ionice -c idle -p $$

wget --limit-rate=200k  -O "/etc/hosts.deny" https://hosts.ubuntu101.co.za/hosts

exit 0

#!/usr/bin/env bash

# NetworkManager sometimes doesn't connect to Wifi/Ethernet on login
# This fixes that issue

set -euo pipefail
echo "Checking connectivity..."

STATUS=$(nmcli networking connectivity check)

if [[ "$STATUS" == "full" ]]; then
  echo "Already online (connectivity: full). Nothing to do."
  exit 0
fi

echo "Offline (status: $STATUS). Searching for best known connection..."

# Only consider ethernet and wifi connections (skip loopback, vpn, virtual, etc.)
BEST=$(nmcli -t -f NAME,AUTOCONNECT-PRIORITY,TYPE con show \
  | awk -F: '
    $3 != "802-3-ethernet" && $3 != "802-11-wireless" { next }
    {
      name=$1; prio=$2+0
      if (prio > max) { max=prio; best=name }
    }
    END { print best }
  ')

if [[ -z "$BEST" ]]; then
  # Fallback: most recently used ethernet/wifi connection by TIMESTAMP
  BEST=$(nmcli -t -f NAME,TIMESTAMP,TYPE con show \
    | awk -F: '
        $3 != "802-3-ethernet" && $3 != "802-11-wireless" { next }
        { print }
      ' \
    | sort -t: -k2 -rn \
    | head -1 \
    | cut -d: -f1)
fi

if [[ -z "$BEST" ]]; then
  echo "No saved connections found. Cannot reconnect."
  exit 1
fi

echo "Attempting to connect to: $BEST"

if nmcli con up id "$BEST"; then
  echo "Connected successfully to '$BEST'."
else
  echo "Failed to connect to '$BEST'." >&2
  exit 1
fi

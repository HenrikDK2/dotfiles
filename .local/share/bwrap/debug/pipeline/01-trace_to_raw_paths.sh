#!/bin/bash

trace_to_raw_paths() {
	awk '
  {
    while (match($0, /\/[a-zA-Z0-9_\/\.\-]+/, m)) {
      path = m[0]

      # reject obvious non-path fragments
      if (path ~ /,/ ) next
      if (path ~ /=$/ ) next

      # normalize /newroot or /oldroot
      sub(/^\/(newroot|oldroot)/, "/", path)

      # normalize repeated slashes
      gsub(/\/+/, "/", path)

      if (path ~ /^\//) {
        if (!seen[path]++) print path
      }

      $0 = substr($0, RSTART + RLENGTH)
    }
  }' "$TRACE_FILE"
}

trace_to_raw_paths

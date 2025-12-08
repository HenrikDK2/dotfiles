#!/bin/bash

# Loop through /etc/fstab
while IFS= read -r line; do
  # Skip comments and blank lines
  [[ "$line" =~ ^# ]] && continue
  [[ -z "$line" ]] && continue

  # Only process UUID lines
  if [[ "$line" =~ ^UUID= ]]; then
    # Split the line
    read -r uuid mount_point format options dump pass <<< "$line"
    new_options="$options"

    # ----------------------------------
    # EXT4: add noatime + commit=60 + lazytime
    # ----------------------------------
    if [[ "$format" == "ext4" ]]; then
      [[ "$new_options" != *noatime* ]]  && new_options="${new_options},noatime"
      [[ "$new_options" != *lazytime* ]] && new_options="${new_options},lazytime"
      [[ "$new_options" != *commit=* ]]  && new_options="${new_options},commit=60"

    # ----------------------------------
    # VFAT: add noatime + flush + fmask/dmask
    # ----------------------------------
    elif [[ "$format" == "vfat" ]]; then
      FMASK=0137
      DMASK=0027

      [[ "$new_options" != *noatime* ]] && new_options="${new_options},noatime"
      [[ "$new_options" != *flush* ]]    && new_options="${new_options},flush"

      new_options="$(echo "$new_options" | sed -E 's/(^|,)fmask=[^,]*//; s/(^|,)dmask=[^,]*//')"
      new_options="${new_options},fmask=$FMASK,dmask=$DMASK"

    # ----------------------------------
    # BTRFS: add performance optimizations
    # ----------------------------------
    elif [[ "$format" == "btrfs" ]]; then
      # Common Btrfs mount options for SSDs and performance
      [[ "$new_options" != *noatime* ]]     && new_options="${new_options},noatime"
      [[ "$new_options" != *compress* ]]    && new_options="${new_options},compress=zstd:1"
      [[ "$new_options" != *space_cache* ]] && new_options="${new_options},space_cache=v2"
      [[ "$new_options" != *ssd* ]]         && new_options="${new_options},ssd"
      [[ "$new_options" != *discard* ]]     && new_options="${new_options},discard"

      # Optional: enable autodefrag if needed (may reduce performance on some workloads)
      # [[ "$new_options" != *autodefrag* ]]  && new_options="${new_options},autodefrag"
    fi

    # ----------------------------------
    # Write back to /etc/fstab
    # Proper escaping prevents breakage
    # ----------------------------------
    new_line="${uuid}\t${mount_point}\t${format}\t${new_options}\t${dump} ${pass}"
    sed -i "s|^$line$|$new_line|" /etc/fstab
  fi
done < /etc/fstab

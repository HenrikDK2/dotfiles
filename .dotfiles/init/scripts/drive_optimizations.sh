#!/bin/bash

while IFS= read -r line; do
  [[ "$line" =~ ^# ]] && continue
  [[ -z "$line" ]] && continue
  
  if [[ "$line" =~ ^UUID= ]]; then
    read -r uuid mount_point format options dump pass <<< "$line"
    new_options="$options"

    if [[ "$format" == "ext4" ]]; then
      [[ "$new_options" != *noatime* ]]  && new_options="${new_options},noatime"
      [[ "$new_options" != *lazytime* ]] && new_options="${new_options},lazytime"
      [[ "$new_options" != *commit=* ]]  && new_options="${new_options},commit=60"

    elif [[ "$format" == "vfat" ]]; then
      if [[ "$mount_point" == "/boot" ]]; then
        FMASK=0077
        DMASK=0077
      else
        FMASK=0137
        DMASK=0027
      fi
      [[ "$new_options" != *noatime* ]] && new_options="${new_options},noatime"
      [[ "$new_options" != *flush* ]]   && new_options="${new_options},flush"
      new_options="$(echo "$new_options" | sed -E 's/(^|,)fmask=[^,]*//; s/(^|,)dmask=[^,]*//')"
      new_options="${new_options},fmask=$FMASK,dmask=$DMASK"

    elif [[ "$format" == "btrfs" ]]; then
      [[ "$new_options" != *noatime* ]]     && new_options="${new_options},noatime"
      [[ "$new_options" != *lazytime* ]]    && new_options="${new_options},lazytime"
      [[ "$new_options" != *commit=* ]]     && new_options="${new_options},commit=60"
      [[ "$new_options" != *compress* ]]    && new_options="${new_options},compress=zstd:1"
      [[ "$new_options" != *space_cache* ]] && new_options="${new_options},space_cache=v2"
      [[ "$new_options" != *ssd* ]]         && new_options="${new_options},ssd"
    fi

    new_line="${uuid}\t${mount_point}\t${format}\t${new_options}\t${dump} ${pass}"
    if [[ "$new_options" == "$options" ]]; then
      echo "  — $format drive already optimized, skipping: $mount_point"
    else
      sudo sed -i "s|^$line$|$new_line|" /etc/fstab
      echo "  ✔ Optimized $format drive: $mount_point"
    fi
  fi
done < /etc/fstab

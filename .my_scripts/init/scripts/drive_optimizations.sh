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

      # Ensure noatime + flush
      [[ "$new_options" != *noatime* ]] && new_options="${new_options},noatime"
      [[ "$new_options" != *flush* ]]    && new_options="${new_options},flush"

      # Remove old fmask/dmask
      new_options="$(echo "$new_options" | sed -E 's/(^|,)fmask=[^,]*//; s/(^|,)dmask=[^,]*//')"

      # Add the updated mask settings
      new_options="${new_options},fmask=$FMASK,dmask=$DMASK"
    fi

    # ----------------------------------
    # Write back to /etc/fstab
    # Proper escaping prevents breakage
    # ----------------------------------
    new_line="${uuid}\t${mount_point}\t${format}\t${new_options}\t${dump} ${pass}"
    sudo sed -i "s|^$line$|$new_line|" /etc/fstab
  fi
done < /etc/fstab

#!/usr/bin/env bash

collapse_filesystem_roots() {
    local exe="$EXECUTABLE"
    local base="${exe##*/}"
    local jobs="${COLLAPSE_JOBS:-8}"

    local tmpdir
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/collapse.XXXXXX")" || return 1

    trap 'rm -rf "$tmpdir"' RETURN

    # ---------------------------------------------------------
    # STEP 1: spool input
    # ---------------------------------------------------------
    local input="$tmpdir/input"

    cat > "$input" || return 1

    local count
    count="$(wc -l < "$input")"
    count="${count//[[:space:]]/}"

    (( count == 0 )) && return 0

    (( jobs > count )) && jobs="$count"
    (( jobs < 1 )) && jobs=1

    # ---------------------------------------------------------
    # STEP 2: split input into balanced chunks
    # ---------------------------------------------------------
    split -n "l/$jobs" -d -- "$input" "$tmpdir/chunk." ||
        return 1

    # ---------------------------------------------------------
    # STEP 3: process chunks in parallel
    # ---------------------------------------------------------
    local -a pids=()
    local chunk output n=0

    for chunk in "$tmpdir"/chunk.*; do
        [[ -f "$chunk" ]] || continue

        output="$tmpdir/result.$n"

        (
            local item path cut_path prefix

            while IFS= read -r item; do
                [[ -z $item ]] && continue

                # Preserve mode:path input format.
                path="${item#*:}"
                [[ $path == "$item" ]] && path=$item

                [[ -n $path && -e $path ]] || continue

                cut_path="$(normalize_path "$path")" || continue
                [[ -n $cut_path ]] || continue

                # ALWAYS strip trailing slash for stable keys.
                cut_path="${cut_path%/}"

                # -------------------------------------------------
                # Executable collapse
                # -------------------------------------------------
                if [[ $cut_path == */"$base"/* ]]; then
                    prefix="${cut_path%%"$base"*}"
                    prefix="${prefix%/}"
                    cut_path="${prefix}/${base}"
                fi

                # -------------------------------------------------
                # Filesystem-root collapse
                # -------------------------------------------------
                case "$cut_path" in
                    /lib/*) cut_path="/lib" ;;
                    /lib64/*) cut_path="/lib64" ;;
                    /lib32/*) cut_path="/lib32" ;;
                    /usr/lib/*) cut_path="/usr/lib" ;;
                    /usr/lib64/*) cut_path="/usr/lib64" ;;
                    /usr/lib32/*) cut_path="/usr/lib32" ;;

                    /etc/gnutls/*) cut_path="/etc/gnutls" ;;
                    /etc/ca-certificates/*) cut_path="/etc/ca-certificates" ;;
                    /usr/share/ca-certificates/*) cut_path="/usr/share/ca-certificates" ;;

                    /usr/share/locale/*) cut_path="/usr/share/locale" ;;
                    /usr/share/X11/locale/*) cut_path="/usr/share/X11/locale" ;;
                    /usr/share/zoneinfo/*) cut_path="/usr/share/zoneinfo" ;;

                    /etc/fonts/* | /etc/fonts/conf.d/*) cut_path="/etc/fonts" ;;
                    /usr/share/fonts/*) cut_path="/usr/share/fonts" ;;
                    /usr/local/share/fonts/*) cut_path="/usr/local/share/fonts" ;;
                    /usr/share/fontconfig/*) cut_path="/usr/share/fontconfig" ;;
                    /var/cache/fontconfig/*) cut_path="/var/cache/fontconfig" ;;
                    "$HOME/.cache/fontconfig"/*) cut_path="$HOME/.cache/fontconfig" ;;
                    "$HOME/.fonts"/*) cut_path="$HOME/.fonts" ;;

                    /usr/share/xkeyboard-config-2/*) cut_path="/usr/share/xkeyboard-config-2" ;;
                    /usr/share/themes/Default/gtk-3.0/*) cut_path="/usr/share/themes/Default/gtk-3.0" ;;
                    "$HOME/.themes"/*) cut_path="$HOME/.themes" ;;
                    /usr/share/icons/*) cut_path="/usr/share/icons" ;;
                    /usr/share/pixmaps/*) cut_path="/usr/share/pixmaps" ;;
                    /usr/share/gtk-3.0/*) cut_path="/usr/share/gtk-3.0" ;;
                    "$HOME/.icons"/*) cut_path="$HOME/.icons" ;;
                    "$HOME/.config/gtk-3.0"/*) cut_path="$HOME/.config/gtk-3.0" ;;
                    "$HOME/.local/share/icons"/*) cut_path="$HOME/.local/share/icons" ;;
                    "$HOME/.local/share/gvfs-metadata"/*) cut_path="$HOME/.local/share/gvfs-metadata" ;;
                    /usr/share/alsa/*) cut_path="/usr/share/alsa" ;;

                    /usr/share/vulkan/*) cut_path="/usr/share/vulkan" ;;
                    "$HOME/.local/share/vulkan"/*) cut_path="$HOME/.local/share/vulkan" ;;
                    /usr/share/libdrm/*) cut_path="/usr/share/libdrm" ;;
                    /usr/share/drirc.d/*) cut_path="/usr/share/drirc.d" ;;
                    /usr/share/glvnd/*) cut_path="/usr/share/glvnd" ;;

                    "$HOME/.cache"/*) cut_path="$HOME/.cache" ;;
                    /var/cache/mesa_shader_cache/*) cut_path="/var/cache/mesa_shader_cache" ;;

                    /usr/share/mime/*) cut_path="/usr/share/mime" ;;
                    "$HOME/.local/share/mime"/*) cut_path="$HOME/.local/share/mime" ;;
                    /usr/share/glib-2.0/*) cut_path="/usr/share/glib-2.0" ;;

                    "$HOME/.local/share/Steam"/*) cut_path="$HOME/.local/share/Steam" ;;
                    "$HOME/.steam"/*) cut_path="$HOME/.steam" ;;
                    /usr/share/steam/compatibilitytools.d*) cut_path="/usr/share/steam/compatibilitytools.d" ;;

                    /sys/devices*) cut_path="/sys/devices" ;;
                    /dev/dri/*) cut_path="/sys/dri" ;;

                    "$HOME/.ssh"/*) cut_path="$HOME/.ssh" ;;
                    "$HOME/.gnupg"/*) cut_path="$HOME/.gnupg" ;;
                    "$HOME/.pki/nssdb"/*) cut_path="$HOME/.pki/nssdb" ;;
                esac

                [[ -n $cut_path && $cut_path != "/" ]] || continue

                printf '%s\n' "$cut_path"

            done < "$chunk"

        ) > "$output" &

        pids+=("$!")
        (( n++ ))
    done

    # ---------------------------------------------------------
    # STEP 4: wait for workers
    # ---------------------------------------------------------
    local pid
    local rc=0

    for pid in "${pids[@]}"; do
        wait "$pid" || rc=1
    done

    (( rc == 0 )) || return "$rc"

    # ---------------------------------------------------------
    # STEP 5: global dedupe
    # ---------------------------------------------------------
    LC_ALL=C sort -u "$tmpdir"/result.* |
        while IFS= read -r path; do
            [[ -n $path && $path != "/" ]] || continue
            printf '%s\n' "$path"
        done
}

collapse_filesystem_roots

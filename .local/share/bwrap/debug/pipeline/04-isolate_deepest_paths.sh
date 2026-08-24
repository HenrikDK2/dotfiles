#!/usr/bin/env bash

isolate_deepest_paths() {
    local item mode path
    local exe="$EXECUTABLE"
    local base="${exe##*/}"

    # Tune with ISOLATE_JOBS=4, 8, etc.
    local jobs="${ISOLATE_JOBS:-8}"

    # ---------------------------------------------------------
    # STEP 0: spool input
    # ---------------------------------------------------------
    local tmpdir
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/isolate.XXXXXX")" || return 1

    # Cleanup even if the pipeline is interrupted.
    trap 'rm -rf "$tmpdir"' RETURN

    local input="$tmpdir/input"
    cat > "$input"

    local count
    count="$(wc -l < "$input")"
    count="${count//[[:space:]]/}"

    (( count == 0 )) && return 0

    # Don't create more workers than useful.
    (( jobs > count )) && jobs="$count"
    (( jobs < 1 )) && jobs=1

    # ---------------------------------------------------------
    # STEP 1: split input into balanced chunks
    #
    # Workers only normalize/check paths here.
    # Ancestor/descendant decisions are deliberately NOT made
    # per worker because those require a global view.
    # ---------------------------------------------------------
    split -n "l/$jobs" -d -- "$input" "$tmpdir/chunk." ||
        return 1

    local -a pids=()
    local chunk n=0
    local output

    for chunk in "$tmpdir"/chunk.*; do
        [[ -f "$chunk" ]] || continue

        output="$tmpdir/result.$n"

        (
            local item mode path

            while IFS= read -r item; do
                [[ -z "$item" ]] && continue

                # Preserve the original mode:path parsing behavior.
                mode="${item%%:*}"
                path="${item#*:}"

                [[ "$path" == "$item" ]] && path="$item"
                [[ -z "$path" ]] && continue

                path="$(normalize_path "$path")" || continue

                [[ -n "$path" && -e "$path" ]] || continue

                printf '%s\n' "$path"
            done < "$chunk"
        ) > "$output" &

        pids+=("$!")
        (( n++ ))
    done

    # ---------------------------------------------------------
    # Wait for all normalization workers.
    # ---------------------------------------------------------
    local rc=0
    local pid

    for pid in "${pids[@]}"; do
        wait "$pid" || rc=1
    done

    (( rc == 0 )) || return "$rc"

    # ---------------------------------------------------------
    # STEP 2: global dedupe + sort
    #
    # This replaces the Bash associative array:
    #
    #   declare -A seen
    #
    # sort -u is implemented in optimized native code and also
    # gives us the ordering required for the deepest-path scan.
    # ---------------------------------------------------------
    local sorted="$tmpdir/sorted"

    LC_ALL=C sort -u "$tmpdir"/result.* > "$sorted" || return 1

    # ---------------------------------------------------------
    # STEP 3: keep only deepest paths
    #
    # This must remain global. An ancestor can be in one worker's
    # chunk while its descendant was processed by another worker.
    #
    # Because paths are sorted lexically, a descendant immediately
    # follows its ancestor's position in the relevant prefix range.
    # ---------------------------------------------------------
    local current next
    local -a paths=()

    mapfile -t paths < "$sorted"

    local i
    local total="${#paths[@]}"

    for (( i = 0; i < total; i++ )); do
        current="${paths[i]}"
        next="${paths[i+1]-}"

        # A path has a descendant iff the next sorted path starts
        # with "current/".
        if [[ -n "$next" && "$next" == "$current/"* ]]; then
            # Keep an executable directory such as /foo/bar/app
            # when it is itself the executable-directory exception.
            if [[ "$current" == */"$base" && -d "$current" ]]; then
                printf '%s\n' "$current"
            fi

            continue
        fi

        printf '%s\n' "$current"
    done
}

isolate_deepest_paths

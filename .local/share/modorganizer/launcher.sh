#!/usr/bin/env bash

STEAMAPPS="${STEAMAPPS_PATH:-$HOME/Games/steamapps}"
COMPATDATA="$STEAMAPPS/compatdata"
MO2_EXE_RELATIVE="pfx/drive_c/Modding/MO2/ModOrganizer.exe"
MO2_INSTALLER_URL="https://github.com/ModOrganizer2/modorganizer/releases/latest/download/Mod.Organizer-2.5.2.exe"
MO2_INSTALLER_CACHE="$HOME/.cache/ModOrganizer2-installer.exe"
TITLE="ModOrganizer 2 — Proton Launcher"

# AppIDs that are runtimes/tools, not games — hidden everywhere in the UI.
# Name-based fallback: any .acf whose name starts with Proton/Steam Linux Runtime/Steamworks is also skipped.
IGNORED_APPIDS=(
    0
    228980    # Steamworks Common Redistributables
    961940    # Proton 3.16 Beta
    1054830   # Proton Experimental
    1070560   # Steam Linux Runtime
    1245040   # Proton EasyAntiCheat Runtime
    1391110   # Steam Linux Runtime 1.0 (scout)
    1420170   # Proton 5.13
    1493710   # Steam Linux Runtime 3.0 (sniper)
    1580130   # Proton 6.3
    1628350   # Steam Linux Runtime 2.0 (soldier)
    1826330   # Proton 8.0
    1887720   # Proton 7.0
    2180100   # Steam Linux Runtime 4.0 (medic)
    2348590   # Proton 9.0
    2739910   # Proton Experimental (new)
    2805730   # Proton Experimental (alt)
    993090    # Lossless Scaling
)

y_info()  { yad --info     --title="$TITLE" --width=450 --text="$1" --button="OK:0"; }
y_warn()  { yad --info     --title="$TITLE" --width=450 --text="$1" --image=dialog-warning --button="OK:0"; }
y_err()   { yad --error    --title="$TITLE" --width=450 --text="$1" --button="OK:0"; }
y_yesno() { yad --question --title="$TITLE" --width=400 --text="$1" --button="Yes:0" --button="No:1"; }

format_path() {
    local path="$1"
    case "$path" in
        "$HOME"/*) echo "~${path#"$HOME"}" ;;
        *) echo "$path" ;;
    esac
}

# Read the game name from its local Steam manifest; fall back to the raw AppID.
appid_to_name() {
    local acf="$STEAMAPPS/appmanifest_${1}.acf"
    if [[ -f "$acf" ]]; then
        grep -m1 '"name"' "$acf" | sed 's/.*"name"[[:space:]]*"\(.*\)"/\1/'
    else
        echo "$1"
    fi
}

# Returns 0 (true) if the AppID should be hidden from all UI lists.
is_ignored() {
    local appid="$1"
    [[ -z "$appid" || "$appid" == "0" ]] && return 0
    for id in "${IGNORED_APPIDS[@]}"; do
        [[ "$appid" == "$id" ]] && return 0
    done
    # Also skip by manifest name prefix so future runtime releases auto-hide.
    local name; name=$(appid_to_name "$appid")
    [[ "$name" =~ ^(Proton|Steam\ Linux\ Runtime|Steamworks) ]] && return 0
    return 1
}

appid_from_path() { echo "$1" | grep -oP '(?<=/compatdata/)\d+(?=/pfx/)'; }

open_folder_for_exe() {
    local exe_path="$1"
    local folder; folder=$(dirname "$exe_path")
    if [[ ! -d "$folder" ]]; then
        y_err "Folder not found:\n$folder"
        return
    fi
    # Try common file managers in order; fall back to xdg-open.
    if   command -v nautilus  &>/dev/null; then nautilus  --no-desktop "$folder" &
    elif command -v thunar    &>/dev/null; then thunar    "$folder" &
    elif command -v dolphin   &>/dev/null; then dolphin   "$folder" &
    elif command -v nemo      &>/dev/null; then nemo      "$folder" &
    elif command -v pcmanfm   &>/dev/null; then pcmanfm   "$folder" &
    elif command -v xdg-open  &>/dev/null; then xdg-open  "$folder" &
    else y_err "No file manager found.\nPath:\n$folder"; fi
}

show_main_screen() {
    local -a rows
    local exe appid name

    declare -A seen

    while IFS= read -r -d '' exe; do
        appid=$(appid_from_path "$exe")
        is_ignored "$appid" && continue

        # Deduplicate
        [[ -n "${seen[$exe]}" ]] && continue
        seen["$exe"]=1

        name=$(appid_to_name "$appid")
        rows+=("$exe" "$appid" "$name" "$(format_path "$exe")")
    done < <(find "$COMPATDATA" -iname "ModOrganizer.exe" -print0 2>/dev/null)

    if [[ ${#rows[@]} -eq 0 ]]; then
        y_warn "No ModOrganizer 2 instances found.\n\nUse 'Install MO2' to set one up."
        show_install_screen
        return
    fi

    # Loop so that "Open Folder" can re-show the dialog without closing permanently.
    while true; do
        local selected
        selected=$(yad --list \
            --title="$TITLE" \
            --text="Select an instance to launch, or use the buttons below." \
            --column="(key)" --column="AppID" --column="Game" --column="Path" \
            --hide-column=1 --print-column=1 \
            --width=1150 --height=600 \
            --button="Open Folder:2" \
            --button="Install MO2:3" \
            --button="Start:0" \
            --button="Exit:1" \
            "${rows[@]}" 2>/dev/null)

        local exit_code=$?

        # Strip trailing pipe that yad appends to row output
        selected="${selected%|}"

        case $exit_code in
            0)  # Start
                [[ -z "$selected" ]] && continue
                launch_instance "$selected"
                return
                ;;
            1|252)  # Exit / window closed
                exit 0
                ;;
            2)  # Open Folder — act directly on the selected row
                [[ -n "$selected" ]] && open_folder_for_exe "$selected"
                # Fall through to loop — main dialog reopens
                ;;
            3)  # Install MO2
                show_install_screen
                return
                ;;
        esac
    done
}

launch_instance() {
    local exe_path="$1"
    local appid; appid=$(appid_from_path "$exe_path")
    if [[ -z "$appid" ]]; then
        y_err "Could not determine AppID from path:\n$exe_path"
        return
    fi
    protontricks-launch --appid "$appid" "$exe_path" &
}

show_install_screen() {
    local -a rows
    local appid name status

    while IFS= read -r -d '' dir; do
        appid=$(basename "$dir")
        [[ "$appid" =~ ^[0-9]+$ ]] || continue
        is_ignored "$appid" && continue
        name=$(appid_to_name "$appid")
        status=$([[ -f "$COMPATDATA/$appid/$MO2_EXE_RELATIVE" ]] && echo "✔ Installed" || echo "—")
        rows+=("$appid" "$name" "$status")
    done < <(find "$COMPATDATA" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

    if [[ ${#rows[@]} -eq 0 ]]; then
        y_warn "No Steam prefixes found under:\n$COMPATDATA\n\nRun a game via Proton at least once first."
        return
    fi

    # Loop so that declining a reinstall returns here instead of the main screen.
    while true; do
        local selected
        selected=$(yad --list \
            --title="$TITLE — Install MO2" \
            --text="Select the game prefix to install ModOrganizer 2 into:" \
            --column="AppID" --column="Game" --column="MO2 Status" \
            --print-column=1 \
            --width=650 --height=550 \
            --button="Install:0" \
            --button="Back:1" \
            "${rows[@]}" 2>/dev/null)

        local exit_code=$?
        selected="${selected%|}"

        case $exit_code in
            1|252)  # Back / window closed
                show_main_screen
                return
                ;;
            0)  # Install
                [[ -z "$selected" ]] && continue
                run_installer "$selected" && return   # Success/error → back to main screen
                ;;
        esac
    done
}

preserve_and_clean_mo2_dir() {
    local dir="$1"

    [[ ! -d "$dir" ]] && return 0

    shopt -s dotglob nullglob

    for item in "$dir"/*; do
        local base
        base=$(basename "$item")

        case "$base" in
            profiles|mods|downloads)
                # Keep these
                continue
                ;;
            *)
                rm -rf "$item"
                ;;
        esac
    done

    shopt -u dotglob nullglob
}

find_mo2_exe() {
    find "$COMPATDATA/$1/pfx" -iname "ModOrganizer.exe" -print -quit 2>/dev/null
}

run_installer() {
    local appid="$1"
    local name; name=$(appid_to_name "$appid")

    if [[ ! -d "$COMPATDATA/$appid/pfx" ]]; then
        y_err "No Proton prefix found for <b>$name</b> (AppID $appid).\n\nRun the game at least once in Steam first."
        return 0
    fi

    local existing; existing=$(find_mo2_exe "$appid")
    if [[ -n "$existing" ]]; then
        if y_yesno "MO2 is already installed for <b>$name</b>.\n\nReinstall and preserve profiles/mods/downloads?"; then
            preserve_and_clean_mo2_dir "$(dirname "$existing")"
        else
            return 1
        fi
    fi

    download_installer || return 0
    protontricks-launch --appid "$appid" "$MO2_INSTALLER_CACHE"

    local dest; dest=$(find_mo2_exe "$appid")
    if [[ -n "$dest" ]]; then
        cp -r "$HOME/.local/share/modorganizer/files/." "$(dirname "$dest")"
    else
        y_warn "Installer finished but ModOrganizer.exe was not found anywhere in the prefix.\n\nDid the installer complete successfully?"
    fi
}

download_installer() {
    [[ -s "$MO2_INSTALLER_CACHE" ]] && return 0

    if ! command -v curl &>/dev/null; then
        y_err "curl is required but not installed."
        return 1
    fi

    (
        curl -L "$MO2_INSTALLER_URL" -o "$MO2_INSTALLER_CACHE" \
            --silent --show-error \
            --write-out "%{percent_download}\n" 2>/dev/null |
        while read -r p; do
            [[ "$p" =~ ^[0-9]+(\.[0-9]+)?$ ]] || continue
            printf "%.0f\n" "$p"
            echo "# Downloading... ${p}%"
        done

        echo "100"
        echo "# Done."
    ) | yad --progress \
        --title="$TITLE" \
        --text="Downloading MO2 installer..." \
        --percentage=0 \
        --auto-close \
        --width=450 \
        --button="Cancel:1"

    if [[ ! -s "$MO2_INSTALLER_CACHE" ]]; then
        y_err "Download failed."
        rm -f "$MO2_INSTALLER_CACHE"
        return 1
    fi
}

command -v yad &>/dev/null || { echo "Error: yad not found. Install with: sudo apt install yad" >&2; exit 1; }
show_main_screen

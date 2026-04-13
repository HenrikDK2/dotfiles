#!/usr/bin/env bash
# launch-mo2.sh — Launch/install ModOrganizer 2 via protontricks-launch
# Game names are read from local Steam .acf manifests (no internet needed).

STEAMAPPS="${STEAMAPPS_PATH:-$HOME/Games/steamapps}"
COMPATDATA="$STEAMAPPS/compatdata"
MO2_EXE_RELATIVE="pfx/drive_c/Modding/MO2/ModOrganizer.exe"
MO2_INSTALLER_URL="https://github.com/ModOrganizer2/modorganizer/releases/latest/download/Mod.Organizer-2.5.2.exe"
MO2_INSTALLER_CACHE="/tmp/ModOrganizer2-installer.exe"
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

# ── Zenity wrappers ───────────────────────────────────────────────────────────
z_info()  { zenity --info     --title="$TITLE" --width=450 --text="$1"; }
z_warn()  { zenity --warning  --title="$TITLE" --width=450 --text="$1"; }
z_err()   { zenity --error    --title="$TITLE" --width=450 --text="$1"; }
z_yesno() { zenity --question --title="$TITLE" --width=400 --text="$1"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

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

# Extract the AppID number embedded in a compatdata path.
appid_from_path() { echo "$1" | grep -oP '(?<=/compatdata/)\d+(?=/pfx/)'; }

# ── Main screen: instance list + Install button ───────────────────────────────
show_main_screen() {
    local -a rows
    local exe appid name

    # Standard installs at the expected path.
    while IFS= read -r -d '' exe; do
        appid=$(appid_from_path "$exe")
        is_ignored "$appid" && continue
        name=$(appid_to_name "$appid")
        rows+=("$exe" "$appid" "$name" "✔ Standard" "$exe")
    done < <(find "$COMPATDATA" -path "*/$MO2_EXE_RELATIVE" -print0 2>/dev/null)

    # Non-standard installs (ModOrganizer.exe found elsewhere in any prefix).
    declare -A seen; for exe in "${rows[@]}"; do seen["$exe"]=1; done
    while IFS= read -r -d '' exe; do
        appid=$(appid_from_path "$exe")
        is_ignored "$appid" && continue
        [[ -n "${seen[$exe]}" ]] && continue
        name=$(appid_to_name "$appid")
        rows+=("$exe" "$appid" "$name" "⚠ Non-standard" "$exe")
    done < <(find "$COMPATDATA" -iname "ModOrganizer.exe" -print0 2>/dev/null)

    if [[ ${#rows[@]} -eq 0 ]]; then
        z_warn "No ModOrganizer 2 instances found.\n\nUse 'Install MO2' to set one up."
        show_install_screen
        return
    fi

    # Column 1 (the exe path) is hidden and used as the return value on OK.
    local selected
    selected=$(zenity --list \
        --title="$TITLE" \
        --text="Select an instance to launch, or click <b>Install MO2</b> to add a new one." \
        --column="(key)" --column="AppID" --column="Game" --column="Status" --column="Path" \
        --hide-column=1 --print-column=1 \
        --width=900 --height=500 \
        --extra-button="Install MO2" \
        "${rows[@]}" 2>/dev/null)

    case "$selected" in
        "Install MO2") show_install_screen ;;
        "")            exit 0 ;;                         # Cancel / window closed
        *)             launch_instance "$selected" ;;
    esac
}

launch_instance() {
    local exe_path="$1"
    local appid; appid=$(appid_from_path "$exe_path")
    if [[ -z "$appid" ]]; then
        z_err "Could not determine AppID from path:\n$exe_path"
        return
    fi
    protontricks-launch --appid "$appid" "$exe_path" &
}

# ── Install screen: pick a prefix, then run the installer ────────────────────
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
        z_warn "No Steam prefixes found under:\n$COMPATDATA\n\nRun a game via Proton at least once first."
        return
    fi

    # Loop so that declining a reinstall returns here instead of the main screen.
    while true; do
        local selected
        selected=$(zenity --list \
            --title="$TITLE — Install MO2" \
            --text="Select the game prefix to install ModOrganizer 2 into:" \
            --column="AppID" --column="Game" --column="MO2 Status" \
            --print-column=1 \
            --width=650 --height=550 \
            "${rows[@]}" 2>/dev/null)

        [[ -z "$selected" ]] && return   # Cancel → back to main screen

        run_installer "$selected" && return   # Success/error → back to main screen
        # run_installer returns 1 when user declined reinstall → loop back here
    done
}

run_installer() {
    local appid="$1"
    local name; name=$(appid_to_name "$appid")
    local dest_dir="$COMPATDATA/$appid/pfx/drive_c/Modding/MO2"

    if [[ ! -d "$COMPATDATA/$appid/pfx" ]]; then
        z_err "No Proton prefix found for <b>$name</b> (AppID $appid).\n\nRun the game at least once in Steam first."
        return 0
    fi

    if [[ -f "$dest_dir/ModOrganizer.exe" ]]; then
        z_yesno "MO2 is already installed for <b>$name</b>.\n\nReinstall anyway?" || return 1
    fi

    download_installer || return 0

    z_info "The MO2 installer will now open for <b>$name</b>.\n\n\
<b>Important:</b> When asked for an install path, use:\n\n\
    <b>C:\\Modding\\MO2</b>"

    protontricks-launch --appid "$appid" "$MO2_INSTALLER_CACHE"

    if [[ -f "$dest_dir/ModOrganizer.exe" ]]; then
        z_info "✔ Installation successful for <b>$name</b>!\n\n$dest_dir/ModOrganizer.exe"
    else
        z_warn "Installer finished but ModOrganizer.exe was not found at:\n$dest_dir\n\nDid you install to C:\\Modding\\MO2?"
    fi
}

download_installer() {
    [[ -s "$MO2_INSTALLER_CACHE" ]] && return 0   # Already cached

    local downloader
    if   command -v wget &>/dev/null; then downloader="wget"
    elif command -v curl &>/dev/null; then downloader="curl"
    else z_err "Neither wget nor curl found.\nInstall one and try again."; return 1
    fi

    (
        if [[ "$downloader" == "wget" ]]; then
            wget -q --show-progress -O "$MO2_INSTALLER_CACHE" "$MO2_INSTALLER_URL" 2>&1 \
                | grep -oP '\d+(?=%)' | while read -r p; do echo "$p"; echo "# Downloading... $p%"; done
        else
            curl -L --progress-bar -o "$MO2_INSTALLER_CACHE" "$MO2_INSTALLER_URL" 2>&1 \
                | grep -oP '\d+\.\d+(?=%)' | while read -r p; do printf "%.0f\n" "$p"; echo "# Downloading... ${p}%"; done
        fi
        echo "100"; echo "# Done."
    ) | zenity --progress --title="$TITLE" --text="Downloading MO2 installer..." \
               --percentage=0 --auto-close --width=450

    if [[ ! -s "$MO2_INSTALLER_CACHE" ]]; then
        z_err "Download failed.\nCheck your internet connection and try again."
        rm -f "$MO2_INSTALLER_CACHE"
        return 1
    fi
}

# ── Entry point ───────────────────────────────────────────────────────────────
command -v zenity &>/dev/null || { echo "Error: zenity not found. Install with: sudo apt install zenity" >&2; exit 1; }

show_main_screen

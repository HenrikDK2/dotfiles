#!/bin/bash

PROFILE="noum2xsj.default"
PROFILE2="5twvy6h9.default-release"
START_LAYOUT=false

merge_prefs() {
    local src="$1" dst="$2"
    local -n skip_keys="$3"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == //* ]] && continue
        key=$(echo "$line" | grep -oP '(?<=user_pref\(")[^"]+')
        [[ -z "$key" ]] && continue
        [[ " ${skip_keys[*]} " == *" $key "* ]] && continue
        if grep -qF "\"$key\"" "$dst"; then
            sed -i "s|.*\"$key\".*|$line|" "$dst"
        else
            echo "$line" >> "$dst"
        fi
    done < "$src"
    echo "  ✔ Merged prefs: $dst"
}

# If running in user env, prevent layout from starting firefox
if pgrep -x layout.sh; then
	START_LAYOUT=true
	killall layout.sh 2>/dev/null
fi

# Kill both thunderbird and firefox
procs="firefox firefox-bin thunderbird thunderbird-bin"
killall $procs 2>/dev/null

for p in $procs; do
	while pgrep -x "$p" > /dev/null 2>&1; do
		sleep 0.5
	done
done

# Firefox
DOTFILES_FIREFOX="$SCRIPT_DIR/user/mozilla/firefox"
FIREFOX_PATHS=(
    "$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
    "$HOME/.config/mozilla/firefox"
)
FIREFOX_SKIP_KEYS=(
    "browser.uiCustomization.state"
)

for FIREFOX_PATH in "${FIREFOX_PATHS[@]}"; do
    if [[ ! -d "$FIREFOX_PATH" && ! -d "$FIREFOX_PATH/$PROFILE" ]]; then
        echo "  ✔ Created profile directory: $FIREFOX_PATH/$PROFILE2"
        mkdir -p "$FIREFOX_PATH/$PROFILE2"
        cp -r "$DOTFILES_FIREFOX/." "$FIREFOX_PATH"
        cp -r "$DOTFILES_FIREFOX/$PROFILE/." "$FIREFOX_PATH/$PROFILE2"
    else
        while IFS= read -r -d '' PREFS_FILE; do
            TARGET="$(dirname "$PREFS_FILE")"
            merge_prefs "$DOTFILES_FIREFOX/$PROFILE/prefs.js" "$PREFS_FILE" FIREFOX_SKIP_KEYS
            rm -rf "$TARGET/chrome"
            cp -r "$DOTFILES_FIREFOX/$PROFILE/chrome" "$TARGET/"
            echo "  ✔ Replaced chrome: $TARGET/chrome"
        done < <(find "$FIREFOX_PATH" -mindepth 2 -maxdepth 2 -name "prefs.js" -print0)
    fi
done

# Thunderbird
THUNDERBIRD_PATHS=(
    "$HOME/.var/app/org.mozilla.Thunderbird/.thunderbird"
    "$HOME/.thunderbird"
)
THUNDERBIRD_SKIP_KEYS=(
    "browser.uiCustomization.state"
    "toolkit.legacyUserProfileCustomizations.stylesheets"
)

for THUNDERBIRD_PATH in "${THUNDERBIRD_PATHS[@]}"; do
    if [[ ! -d "$THUNDERBIRD_PATH" && ! -d "$THUNDERBIRD_PATH/$PROFILE" ]]; then
        echo "  ✔ Created profile directory: $THUNDERBIRD_PATH/$PROFILE2"
        mkdir -p "$THUNDERBIRD_PATH/$PROFILE2"
    else
        while IFS= read -r -d '' PREFS_FILE; do
            TARGET="$(dirname "$PREFS_FILE")"
            merge_prefs "$DOTFILES_FIREFOX/$PROFILE/prefs.js" "$PREFS_FILE" THUNDERBIRD_SKIP_KEYS
        done < <(find "$THUNDERBIRD_PATH" -mindepth 2 -maxdepth 2 -name "prefs.js" -print0)
    fi
done

if [ "$START_LAYOUT" = true ]; then
	setsid ~/.config/hypr/layout.sh &>/dev/null &
fi

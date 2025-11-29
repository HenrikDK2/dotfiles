#!/bin/bash

local shared_exclude_patterns=(
	-not -path "*/_redist/*"
	-not -path "*/windows/**"
	-not -path "*/system32/*" \
	-not -path "*/Internet Explorer/*"
	-not -path "*/Windows Media Player/*"
	-not -path "*/Windows NT/**"
	-not -path "*/*uninstall*/*"
   	-not -path "*/*installers*/*"
   	-not -path "*/_redist/*"

   	# File name exclusions
   	-not -name "*install*"
   	-not -name "*Install*"
   	-not -name "*CrashReport*"
   	-not -name "*CrashHandler*"
   	-not -name "*crash_handler*"
   	-not -name "*redist*"
   	-not -name "*dotnet-*"
   	-not -name "*Setup*"
   	-not -name "*SETUP*"
   	-not -name "*setup*"
)

if command -v piactl; then
	# Define the Steam games directory and the PIA settings file
	STEAM_DIR="$HOME/.local/share/Steam/steamapps/common"
	HEROIC_DIR="$HOME/Games/Heroic"

	PIA_SETTINGS_FILE="/opt/piavpn/etc/settings.json"

	# Extract the existing splitTunnelRules from the settings file
	existing_rules=$(jq '.splitTunnelRules' "$PIA_SETTINGS_FILE")
	echo "Existing rules loaded."

	TEMP_EXECS=$(mktemp)

	# Adding games
	find "$STEAM_DIR" -type f \( -name "*.x86_64" -or -name "*.exe" \) \
		-not -path "*/*Proton*/*" \
		-not -path "*/steamapps/common/wallpaper_engine*/*" \
		-not -path "*/steamapps/common/Steamworks Shared/*" \
		"${shared_exclude_patterns[@]}" > "$TEMP_EXECS"

    find "$HEROIC_DIR" -type f \( -name "*.x86_64" -or -name "*.exe" \) \
        -not -path "*/Prefixes/*" \
		"${shared_exclude_patterns[@]}" >> "$TEMP_EXECS"

	# Initialize updated_rules as the existing rules
	updated_rules="$existing_rules"

	# Counter for stats
	new_rules_added=0
	skipped_duplicates=0

	# Process each executable path
	while read -r exec; do
	    # Check if this path already exists in the rules
	    path_exists=$(echo "$updated_rules" | jq --arg path "$exec" 'map(.path == $path) | any')
	    
	    if [[ "$path_exists" == "true" ]]; then
	        echo "Skipping duplicate: $exec"
	        ((skipped_duplicates++))
	        continue
	    fi
	    
	    # Construct the rule (mode: "exclude" for blocking the VPN for these executables)
	    new_rule=$(jq -n --arg exec_path "$exec" '{"linkTarget": "", "mode": "exclude", "path": $exec_path}')
	    echo "Adding new rule for: $exec"
	    
	    # Append the new rule to the existing rules
	    updated_rules=$(echo "$updated_rules" | jq ". + [$new_rule]")
	    ((new_rules_added++))
	done < "$TEMP_EXECS"

	# Clean up temp file
	rm "$TEMP_EXECS"

	# Print stats
	echo "------------------------------------"
	echo "Rules added: $new_rules_added"
	echo "Duplicates skipped: $skipped_duplicates"
	echo "Total rules now: $(echo "$updated_rules" | jq 'length')"
	echo "------------------------------------"

	# Apply the updated splitTunnelRules using piactl
	piactl -u applysettings "{\"splitTunnelRules\": $updated_rules}"
fi

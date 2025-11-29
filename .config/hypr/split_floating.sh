#!/bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed."
    exit 1
fi

# Get current workspace and active window
WORKSPACE_ID=$(hyprctl activeworkspace -j | jq -r '.id')
ACTIVE_WINDOW=$(hyprctl activewindow -j | jq -r '.address')
STATE_FILE="/tmp/hypr-split-state-$WORKSPACE_ID"

# Get windows on current workspace (excluding special windows)
windows=$(hyprctl clients -j | jq -r \
    '.[] | select(.workspace.id == '"$WORKSPACE_ID"' and .monitor != null) | 
     .address + " " + (.floating|tostring) + " " + (.at[0]|tostring) + " " + (.at[1]|tostring) + " " + 
     (.size[0]|tostring) + " " + (.size[1]|tostring)')

# Convert to array
mapfile -t window_array <<< "$windows"

# Check if we have exactly 2 windows
if [ "${#window_array[@]}" -ne 2 ]; then
    echo "Need exactly 2 windows to split."
    exit 1
fi

# Get monitor info
monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)')
monitor_width=$(echo "$monitor" | jq -r '.width')
monitor_height=$(echo "$monitor" | jq -r '.height')
monitor_x=$(echo "$monitor" | jq -r '.x')
monitor_y=$(echo "$monitor" | jq -r '.y')

# Check current state
if [ -f "$STATE_FILE" ]; then
    # Restore original state
    saved_active=$(head -n 1 "$STATE_FILE")

    while IFS= read -r line; do
        [[ "$line" == "$saved_active" ]] && continue

        IFS=' ' read -r addr floating orig_x orig_y orig_w orig_h <<< "$line"

        # Move window back to original workspace if needed
        current_ws=$(hyprctl clients -j | jq -r '.[] | select(.address == "'$addr'") | .workspace.id')
        if [ "$current_ws" != "$WORKSPACE_ID" ]; then
            hyprctl dispatch movetoworkspacesilent "$WORKSPACE_ID,address:$addr"
        fi

        if [ "$floating" = "false" ]; then
            hyprctl dispatch togglefloating "address:$addr"
        fi

        hyprctl dispatch movewindowpixel "exact $orig_x $orig_y,address:$addr"
        hyprctl dispatch resizewindowpixel "exact $orig_w $orig_h,address:$addr"
    done < <(tail -n +2 "$STATE_FILE")

    hyprctl dispatch focuswindow "address:$saved_active"
    rm "$STATE_FILE"
    hyprctl --batch "keyword general:border_size 1 ; keyword decoration:rounding 5"
else
    # Save original state
    > "$STATE_FILE"
    echo "$ACTIVE_WINDOW" >> "$STATE_FILE"

    for window in "${window_array[@]}"; do
        echo "$window" >> "$STATE_FILE"
    done

    # Split windows
    half_width=$((monitor_width / 2))

    for i in "${!window_array[@]}"; do
        IFS=' ' read -r addr _ <<< "${window_array[$i]}"

        hyprctl dispatch movetoworkspacesilent "$WORKSPACE_ID,address:$addr"
        hyprctl dispatch focuswindow "address:$addr"
        hyprctl dispatch togglefloating "address:$addr"

        pos_x=$(( i == 0 ? monitor_x : monitor_x + half_width ))
        hyprctl dispatch movewindowpixel "exact $pos_x $monitor_y,address:$addr"
        hyprctl dispatch resizewindowpixel "exact $half_width $monitor_height,address:$addr"
    done

    hyprctl dispatch focuswindow "address:$ACTIVE_WINDOW"
    hyprctl --batch "keyword general:border_size 0 ; keyword decoration:rounding 0"
fi


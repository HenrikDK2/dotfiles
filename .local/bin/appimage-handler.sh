#!/bin/bash
# AppImage handler script for Nemo
 
APPIMAGE="$1"
 
# Check if file exists and is an AppImage
if [ ! -f "$APPIMAGE" ]; then
    zenity --error --text="File not found: $APPIMAGE"
    exit 1
fi
 
# Check if it's actually an AppImage
if ! file "$APPIMAGE" | grep -q "ELF.*executable"; then
    zenity --error --text="This doesn't appear to be a valid AppImage file."
    exit 1
fi
 
# Check if already executable
if [ -x "$APPIMAGE" ]; then
    # Already executable, just run it
    "$APPIMAGE" &
    exit 0
fi
 
# Show dialog asking if user wants to make it executable and run
zenity --question \
    --title="AppImage Permissions" \
    --text="This AppImage does not have executable permissions.\n\nDo you want to make it executable and run it?" \
    --width=400
 
if [ $? -eq 0 ]; then
    # User clicked Yes
    chmod +x "$APPIMAGE"
    if [ $? -eq 0 ]; then
        "$APPIMAGE" &
        exit 0
    else
        zenity --error --text="Failed to set executable permissions.\n\nYou may need to run:\nchmod +x \"$APPIMAGE\""
        exit 1
    fi
else
    # User clicked No or closed dialog
    exit 0
fi
 

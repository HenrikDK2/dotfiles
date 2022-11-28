#!/bin/sh

DIR="$HOME/.cache"

grim -g "$(slurp)" "$DIR/clipboard.jpg"
tesseract "$DIR/clipboard.jpg" "$DIR/clipboard"
wl-copy < $DIR/clipboard.txt
rm $DIR/clipboard.txt
rm $DIR/clipboard.jpg

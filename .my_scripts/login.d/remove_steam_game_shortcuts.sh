#!/bin/bash

find "$HOME/.local/share/applications" -name '*.desktop' -exec grep -l 'Exec=steam steam://rungameid/' {} \; -delete;
find "$HOME" -maxdepth 1 -name '*.desktop' -exec grep -l 'Exec=steam steam://rungameid/' {} \; -delete

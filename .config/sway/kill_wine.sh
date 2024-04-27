#!/bin/bash

pkill -f '\.exe$'  # This kills processes with .exe extension
pkill -f 'wine'    # This kills Wine processes

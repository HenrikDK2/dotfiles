#!/usr/bin/env bash

set -euo pipefail

NEW_PATH="$HOME"

# Directories to process
TARGET_DIRS=(
  "$HOME/.config"
  "$HOME/.local/share"
)

# Folders to ignore (case-insensitive)
IGNORE_DIRS=(
  "steam"
  "games"
  "dotfiles"
  "trash"
  "klipper"
)

echo "⚙️  Starting path fix..."
echo "Replacing any /home/<USERNAME>/ with path $NEW_PATH/"
echo ""

# Build prune expression dynamically for find
PRUNE_EXPR=()
for dir in "${IGNORE_DIRS[@]}"; do
  PRUNE_EXPR+=( -iname "*$dir*" -o )
done
unset 'PRUNE_EXPR[${#PRUNE_EXPR[@]}-1]'  # Remove trailing -o

# Iterate over target directories
for base in "${TARGET_DIRS[@]}"; do
  echo "📂 Processing directory: $base"

  find "$base" \
    \( "${PRUNE_EXPR[@]}" \) -prune -o \
    -type f -print0 |
  while IFS= read -r -d '' file; do

    # Only process text files
    if file "$file" | grep -q text; then

      # Check if file contains a /home/.../ path that is NOT $NEW_PATH
      if grep -qE "/home/[^/]+/" "$file" && ! grep -qF "$NEW_PATH/" "$file"; then
        echo "🔧 Fixing paths in: $file"

        # Replace /home/USERNAME/ with current user's home
        sed -i -E "s|/home/[^/]+/|$NEW_PATH/|g" "$file"
      fi

    fi
  done
done

echo ""
echo "✅ Path fixing complete!"

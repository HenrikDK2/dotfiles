#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/pjobson/Microsoft-Fonts.git"
SPARSE_PATH="2021 - Windows 11/ttf"
FONT_DIR="/usr/local/share/fonts/microsoft"
TMP_DIR="$(mktemp -d)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

install_fonts() {
  info "Installing Microsoft fonts to $FONT_DIR ..."
  info "Cloning font repository (sparse) …"
  git clone \
    --depth=1 \
    --filter=blob:none \
    --sparse \
    --quiet \
    "$REPO_URL" \
    "$TMP_DIR/repo"

  cd "$TMP_DIR/repo"
  git sparse-checkout set "$SPARSE_PATH"
  git checkout --quiet

  mkdir -p "$FONT_DIR"
  TTF_SRC="$TMP_DIR/repo/$SPARSE_PATH"
  INSTALLED=0
  SKIPPED=0

  while IFS= read -r -d '' gz_file; do
    # Derive a clean font name: strip the hash suffix and .ttf.gz extension
    base="$(basename "$gz_file")"                   # e.g. "Calibri - 3dea6d....ttf.gz"
    font_name="$(echo "$base" | sed 's/ - [a-f0-9]*\.ttf\.gz$/.ttf/')"
    dest="$FONT_DIR/$font_name"

    if [[ -f "$dest" ]]; then
      ((SKIPPED++)) || true
      continue
    fi

    gzip -dc "$gz_file" > "$dest"
    chmod 644 "$dest"
    ((INSTALLED++)) || true
  done < <(find "$TTF_SRC" -maxdepth 1 -name "*.ttf.gz" -print0 | sort -z)

  info "Updating font cache …"
  fc-cache -f "$FONT_DIR"
  rm -rf "$TMP_DIR"
  info "Done! Installed: $INSTALLED font(s)  |  Skipped (already present): $SKIPPED"
  info "Fonts available in: $FONT_DIR"
}

# Check if dependencies are installed
for cmd in git gzip fc-cache; do
  command -v "$cmd" &>/dev/null || error "'$cmd' is required but not installed."
done

# Skip if already installed
if [[ -d "$FONT_DIR" ]] && [[ -n "$(ls -A "$FONT_DIR" 2>/dev/null)" ]]; then
  FONT_COUNT=$(ls "$FONT_DIR"/*.ttf 2>/dev/null | wc -l)
  info "Microsoft fonts already installed at $FONT_DIR ($FONT_COUNT fonts found). Skipping."
else
  install_fonts
fi

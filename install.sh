#!/bin/bash
#
# claude-statusline installer
#
# What it does:
#   1. checks for jq
#   2. copies statusline.sh -> ~/.claude/statusline.sh (+ executable)
#   3. backs up ~/.claude/settings.json, then merges in the statusLine entry
#      (if a statusLine already exists, it shows it and asks before replacing)
#
# Usage:
#   ./install.sh
#
# Safe to re-run. Nothing is deleted; settings.json is backed up before any edit.

set -euo pipefail

# --- locate things --------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/statusline.sh"
CLAUDE_DIR="$HOME/.claude"
DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

c_info()  { printf '\033[36m%s\033[0m\n' "$1"; }     # cyan
c_ok()    { printf '\033[32m%s\033[0m\n' "$1"; }     # green
c_warn()  { printf '\033[33m%s\033[0m\n' "$1"; }     # yellow
c_err()   { printf '\033[31m%s\033[0m\n' "$1" >&2; } # red

# --- 1. dependency check --------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  c_err "jq is required but not found."
  case "$(uname -s)" in
    Darwin) c_err "  install it with:  brew install jq" ;;
    Linux)  c_err "  install it with:  sudo apt install jq   (or your package manager)" ;;
    *)      c_err "  see: https://jqlang.github.io/jq/download/" ;;
  esac
  exit 1
fi

if [ ! -f "$SRC" ]; then
  c_err "statusline.sh not found next to this installer ($SRC)."
  exit 1
fi

# --- 2. install the script ------------------------------------------------
mkdir -p "$CLAUDE_DIR"
cp "$SRC" "$DEST"
chmod +x "$DEST"
c_ok "Installed statusline.sh -> $DEST"

# --- 3. merge settings.json ----------------------------------------------
NEW_STATUSLINE=$(jq -n --arg cmd "$DEST" '{type: "command", command: $cmd}')

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
  c_info "Created $SETTINGS"
fi

# Validate existing settings is real JSON before we touch it.
if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  c_err "$SETTINGS is not valid JSON. Fix or remove it, then re-run."
  exit 1
fi

# If a statusLine already exists, show it and ask.
EXISTING=$(jq '.statusLine // empty' "$SETTINGS")
if [ -n "$EXISTING" ]; then
  c_warn "An existing statusLine was found in $SETTINGS:"
  printf '%s\n' "$EXISTING" | jq .
  printf 'Replace it with claude-statusline? [y/N] '
  read -r reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) c_info "Left your settings unchanged. statusline.sh is installed at:"
       c_info "  $DEST"
       c_info "Point your settings.json statusLine.command at it whenever you like."
       exit 0 ;;
  esac
fi

# Back up, then merge.
BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"
c_info "Backed up settings -> $BACKUP"

TMP=$(mktemp)
jq --argjson sl "$NEW_STATUSLINE" '.statusLine = $sl' "$SETTINGS" > "$TMP"
mv "$TMP" "$SETTINGS"

c_ok "Done. claude-statusline is now your Claude Code status line."
c_info "Open a Claude Code session to see it. To undo, restore: $BACKUP"

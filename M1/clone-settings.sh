#!/usr/bin/env bash
#
# Clone current machine settings into this repo for replicating on another Mac
# (e.g. Mac Studio). Run this on your SOURCE machine (current Mac).
#
# Usage: ./clone-settings.sh
#

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONED_DIR="$SCRIPT_DIR/cloned"
HOME_DIR="${HOME:-$HOME}"

echo "Cloning settings from $HOME_DIR into $CLONED_DIR ..."
mkdir -p "$CLONED_DIR"/{dotfiles,ssh,cursor,vscode,rectangle}

# ---- Dotfiles ----
for f in .gitconfig .npmrc .zprofile; do
  if [[ -f "$HOME_DIR/$f" ]]; then
    cp "$HOME_DIR/$f" "$CLONED_DIR/dotfiles/$f"
    echo "  cloned dotfiles/$f"
  fi
done

# .zshrc: copy but redact secrets (tokens, keys)
if [[ -f "$HOME_DIR/.zshrc" ]]; then
  sed 's|^export GITHUB_PERSONAL_ACCESS_TOKEN=.*|export GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token 2>/dev/null)  # or set manually|' \
      "$HOME_DIR/.zshrc" > "$CLONED_DIR/dotfiles/.zshrc"
  # Keep only first token line if there were duplicates
  awk '/GITHUB_PERSONAL_ACCESS_TOKEN/ { if (++n==1) print; next } 1' "$CLONED_DIR/dotfiles/.zshrc" > "$CLONED_DIR/dotfiles/.zshrc.tmp" && mv "$CLONED_DIR/dotfiles/.zshrc.tmp" "$CLONED_DIR/dotfiles/.zshrc"
  echo "  cloned dotfiles/.zshrc (tokens redacted)"
fi

# ---- SSH (config and known_hosts only; never private keys) ----
if [[ -f "$HOME_DIR/.ssh/config" ]]; then
  cp "$HOME_DIR/.ssh/config" "$CLONED_DIR/ssh/config"
  echo "  cloned ssh/config"
fi
if [[ -f "$HOME_DIR/.ssh/known_hosts" ]]; then
  cp "$HOME_DIR/.ssh/known_hosts" "$CLONED_DIR/ssh/known_hosts"
  echo "  cloned ssh/known_hosts"
fi

# ---- Homebrew ----
if command -v brew &>/dev/null; then
  brew bundle dump --file="$SCRIPT_DIR/Brewfile" --force 2>/dev/null || true
  echo "  created Brewfile (brew bundle dump)"
fi

# ---- Cursor ----
CURSOR_USER="$HOME_DIR/Library/Application Support/Cursor/User"
if [[ -f "$CURSOR_USER/settings.json" ]]; then
  cp "$CURSOR_USER/settings.json" "$CLONED_DIR/cursor/settings.json"
  echo "  cloned cursor/settings.json"
fi
if [[ -f "$CURSOR_USER/keybindings.json" ]]; then
  cp "$CURSOR_USER/keybindings.json" "$CLONED_DIR/cursor/keybindings.json"
  echo "  cloned cursor/keybindings.json"
fi

# ---- VSCode ----
VSCODE_USER="$HOME_DIR/Library/Application Support/Code/User"
if [[ -f "$VSCODE_USER/settings.json" ]]; then
  cp "$VSCODE_USER/settings.json" "$CLONED_DIR/vscode/settings.json"
  echo "  cloned vscode/settings.json"
fi

# ---- Rectangle (window manager) ----
RECTANGLE_PREFS="$HOME_DIR/Library/Preferences/com.knollsoft.Rectangle.plist"
if [[ -f "$RECTANGLE_PREFS" ]]; then
  cp "$RECTANGLE_PREFS" "$CLONED_DIR/rectangle/com.knollsoft.Rectangle.plist"
  echo "  cloned rectangle/com.knollsoft.Rectangle.plist"
fi

echo ""
echo "Done. Cloned files are under: $CLONED_DIR"
echo "Next: commit and push, then on the new Mac run: ./replicate.sh"

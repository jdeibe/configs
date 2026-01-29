#!/usr/bin/env bash
#
# Replicate settings on a new Mac (e.g. Mac Studio) from cloned configs.
# Run this on the TARGET machine after cloning this repo.
#
# Prerequisites:
#   - Xcode CLI tools (xcode-select --install)
#   - This repo cloned (e.g. into ~/repos/configs)
#
# Usage:
#   cd ~/repos/configs/M1
#   ./replicate.sh              # full: dotfiles + brew + editor settings
#   ./replicate.sh --dotfiles   # only copy dotfiles and ssh config
#   ./replicate.sh --brew       # only run Brewfile
#   ./replicate.sh --scripts   # only run init, os, apps, zsh scripts
#

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONED_DIR="$SCRIPT_DIR/cloned"
HOME_DIR="${HOME:-$HOME}"

usage() {
  echo "Usage: $0 [--dotfiles] [--brew] [--scripts] [--cursor] [--vscode] [--rectangle]"
  echo "  No options: run full replication (dotfiles, brew, scripts, cursor, vscode, rectangle)."
  echo "  --dotfiles   Copy dotfiles and ssh config to \$HOME"
  echo "  --brew       Install from Brewfile"
  echo "  --scripts    Run init.sh, os.sh, apps.sh, zsh.sh (needs sudo)"
  echo "  --cursor     Copy Cursor editor settings"
  echo "  --vscode     Copy VSCode editor settings"
  echo "  --rectangle  Copy Rectangle window manager preferences"
}

do_dotfiles=0
do_brew=0
do_scripts=0
do_cursor=0
do_vscode=0
do_rectangle=0

if [[ $# -eq 0 ]]; then
  do_dotfiles=1
  do_brew=1
  do_scripts=1
  do_cursor=1
  do_vscode=1
  do_rectangle=1
else
  for arg in "$@"; do
    case "$arg" in
      --dotfiles)  do_dotfiles=1 ;;
      --brew)      do_brew=1 ;;
      --scripts)   do_scripts=1 ;;
      --cursor)    do_cursor=1 ;;
      --vscode)    do_vscode=1 ;;
      --rectangle) do_rectangle=1 ;;
      -h|--help)   usage; exit 0 ;;
      *)           echo "Unknown option: $arg"; usage; exit 1 ;;
    esac
  done
fi

# ---- Setup scripts first (init installs Homebrew) ----
if [[ $do_scripts -eq 1 ]]; then
  echo "Running setup scripts (will prompt for sudo) ..."
  [[ -f "$SCRIPT_DIR/init.sh" ]] && bash "$SCRIPT_DIR/init.sh"
  [[ -f "$SCRIPT_DIR/os.sh" ]]   && bash "$SCRIPT_DIR/os.sh"
  [[ -f "$SCRIPT_DIR/apps.sh" ]] && bash "$SCRIPT_DIR/apps.sh"
  [[ -f "$SCRIPT_DIR/zsh.sh" ]]  && bash "$SCRIPT_DIR/zsh.sh"
fi

# ---- Dotfiles ----
if [[ $do_dotfiles -eq 1 ]]; then
  if [[ ! -d "$CLONED_DIR/dotfiles" ]]; then
    echo "No cloned dotfiles found at $CLONED_DIR/dotfiles. Run clone-settings.sh on the source Mac first."
    exit 1
  fi
  echo "Copying dotfiles to $HOME_DIR ..."
  for f in .gitconfig .npmrc .zshrc .zprofile; do
    if [[ -f "$CLONED_DIR/dotfiles/$f" ]]; then
      cp "$CLONED_DIR/dotfiles/$f" "$HOME_DIR/$f"
      echo "  installed $f"
    fi
  done
  if [[ -f "$CLONED_DIR/ssh/config" ]]; then
    mkdir -p "$HOME_DIR/.ssh"
    cp "$CLONED_DIR/ssh/config" "$HOME_DIR/.ssh/config"
    echo "  installed .ssh/config"
  fi
  if [[ -f "$CLONED_DIR/ssh/known_hosts" ]]; then
    mkdir -p "$HOME_DIR/.ssh"
    cat "$CLONED_DIR/ssh/known_hosts" >> "$HOME_DIR/.ssh/known_hosts" 2>/dev/null || cp "$CLONED_DIR/ssh/known_hosts" "$HOME_DIR/.ssh/known_hosts"
    echo "  installed .ssh/known_hosts"
  fi
  echo "Dotfiles done. Add SSH keys manually (they are not cloned)."
fi

# ---- Brewfile ----
if [[ $do_brew -eq 1 ]] && [[ -f "$SCRIPT_DIR/Brewfile" ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Run ./init.sh first or install from https://brew.sh"
    exit 1
  fi
  echo "Installing from Brewfile ..."
  brew bundle --file="$SCRIPT_DIR/Brewfile"
fi

# ---- Cursor ----
if [[ $do_cursor -eq 1 ]] && [[ -f "$CLONED_DIR/cursor/settings.json" ]]; then
  CURSOR_USER="$HOME_DIR/Library/Application Support/Cursor/User"
  mkdir -p "$CURSOR_USER"
  cp "$CLONED_DIR/cursor/settings.json" "$CURSOR_USER/settings.json"
  [[ -f "$CLONED_DIR/cursor/keybindings.json" ]] && cp "$CLONED_DIR/cursor/keybindings.json" "$CURSOR_USER/keybindings.json"
  echo "Cursor settings installed."
fi

# ---- VSCode ----
if [[ $do_vscode -eq 1 ]] && [[ -f "$CLONED_DIR/vscode/settings.json" ]]; then
  VSCODE_USER="$HOME_DIR/Library/Application Support/Code/User"
  mkdir -p "$VSCODE_USER"
  cp "$CLONED_DIR/vscode/settings.json" "$VSCODE_USER/settings.json"
  echo "VSCode settings installed."
fi

# ---- Rectangle (window manager) ----
if [[ $do_rectangle -eq 1 ]] && [[ -f "$CLONED_DIR/rectangle/com.knollsoft.Rectangle.plist" ]]; then
  mkdir -p "$HOME_DIR/Library/Preferences"
  cp "$CLONED_DIR/rectangle/com.knollsoft.Rectangle.plist" "$HOME_DIR/Library/Preferences/com.knollsoft.Rectangle.plist"
  echo "Rectangle preferences installed."
fi

echo ""
echo "Replicate done. Log out or restart for some OS/shell changes to take effect."

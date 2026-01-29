#!/usr/bin/env bash
#
# Install zsh, Oh My Zsh, and all completion plugins in one go.
# Runs zsh.sh then zsh-plugins.sh.
#
# Prerequisites: Homebrew (run init.sh first).
#
# Usage: ./install-zsh-all.sh
#

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1/2 zsh + Oh My Zsh + ZPlug ==="
bash "$SCRIPT_DIR/zsh.sh"

echo ""
echo "=== 2/2 zsh plugins (autosuggestions, completions, claude) ==="
bash "$SCRIPT_DIR/zsh-plugins.sh"

echo ""
echo "Done. To use the full config (completions, autosuggestions, claude):"
echo "  cp $SCRIPT_DIR/cloned/dotfiles/.zshrc ~/.zshrc"
echo "  rm -f ~/.zcompdump* && exec zsh"

#!/usr/bin/env bash
#
# Install zsh plugins: autosuggestions, completions, and Claude CLI completion.
# (Menus/descriptions for tab-completion; history suggestions; claude -- Tab.)
#
# Requires: Oh My Zsh (run zsh.sh first).
#
# Usage: ./zsh-plugins.sh
#

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH="${ZSH:-$HOME/.oh-my-zsh}"
CUSTOM_PLUGINS="${ZSH}/custom/plugins"

if [[ ! -d "$ZSH" ]]; then
  echo "Oh My Zsh not found at $ZSH. Run ./zsh.sh first."
  exit 1
fi

mkdir -p "$CUSTOM_PLUGINS"

install_plugin() {
  local name="$1"
  local repo="$2"
  local dir="$CUSTOM_PLUGINS/$name"
  if [[ -d "$dir" ]]; then
    echo "  $name already installed, updating..."
    (cd "$dir" && git pull --quiet 2>/dev/null || true)
  else
    echo "  Installing $name..."
    git clone --depth 1 "https://github.com/$repo" "$dir"
  fi
}

echo "Installing zsh plugins..."
install_plugin zsh-autosuggestions       zsh-users/zsh-autosuggestions
install_plugin zsh-completions           zsh-users/zsh-completions
install_plugin zsh-claudecode-completion wbingli/zsh-claudecode-completion

echo ""
echo "Plugins installed to $CUSTOM_PLUGINS"
echo ""
echo "To enable them, use this repo's .zshrc (it already has the right config):"
echo "  plugins=(git zsh-autosuggestions zsh-completions)"
echo "  + fpath entry for Claude completion (no plugin entry; avoids overwrite prompt)"
echo ""
echo "  cp $SCRIPT_DIR/cloned/dotfiles/.zshrc ~/.zshrc"
echo "  rm -f ~/.zcompdump* && exec zsh"
echo ""

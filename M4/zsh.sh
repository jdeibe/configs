#!/usr/bin/env bash
#
# Install zsh, Oh My Zsh, and ZPlug. Register zsh as default shell.
#
# Prerequisites: Homebrew (run init.sh first).
#
# Usage: ./zsh.sh
#

set -e

# Zsh and default shell
brew install zsh
zsh_path=$(which zsh)
grep -Fxq "$zsh_path" /etc/shells || sudo bash -c "echo $zsh_path >> /etc/shells"
chsh -s "$zsh_path" "${USER:-$(whoami)}"

# Oh My Zsh (required for cloned .zshrc and zsh-plugins.sh)
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "Oh My Zsh already installed at $HOME/.oh-my-zsh"
fi

# ZPlug
brew install zplug

echo ""
echo "Done. Next: ./zsh-plugins.sh or ./install-zsh-all.sh (if you haven’t already)."

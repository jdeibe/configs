#!/bin/bash

# Installs zsh and Oh My Zsh, registers zsh as a default shell
brew install zsh
zsh_path=$(which zsh)
grep -Fxq "$zsh_path" /etc/shells || sudo bash -c "echo $zsh_path >> /etc/shells"
chsh -s "$zsh_path" $USER

# Install Oh My Zsh (required for cloned .zshrc and zsh-plugins.sh)
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "Oh My Zsh already installed at $HOME/.oh-my-zsh"
fi

# Install ZPlug (https://github.com/zplug/zplug)
brew install zplug

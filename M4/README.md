# M4 / Apple Silicon Mac setup

Scripts to set up and replicate your Mac environment (e.g. from a MacBook to a Mac Studio).

## Workflow

### 1. On your current Mac (source)

Clone your current settings into this repo:

```bash
cd ~/repos/configs/M4
./clone-settings.sh
```

This copies into `M4/cloned/`:

- **Dotfiles:** `.gitconfig`, `.zshrc`, `.zprofile`, `.npmrc` (tokens in `.zshrc` are redacted)
- **SSH:** `config` and `known_hosts` only (never private keys)
- **Homebrew:** `Brewfile` (all formulae and casks)
- **Cursor:** `settings.json`, `keybindings.json`
- **VSCode:** `settings.json`
- **Rectangle:** window manager preferences (`com.knollsoft.Rectangle.plist`)

Commit and push so the new Mac can pull the repo.

### 2. On the new Mac (e.g. Mac Studio)

Clone this repo, then run:

```bash
cd ~/repos/configs/M4
./replicate.sh
```

This will:

1. Copy dotfiles and SSH config into `$HOME`
2. Run `brew bundle` from `Brewfile`
3. Run `init.sh`, `os.sh`, `apps.sh`, `zsh.sh` (install Homebrew, set OS defaults, install apps, set up zsh)
4. Install Cursor and VSCode settings

**Options** (run only what you need):

```bash
./replicate.sh --dotfiles   # only dotfiles + ssh
./replicate.sh --brew       # only Brewfile
./replicate.sh --scripts   # only init, os, apps, zsh
./replicate.sh --cursor    # only Cursor settings
./replicate.sh --vscode    # only VSCode settings
./replicate.sh --rectangle # only Rectangle window manager prefs
```

### After replicate

- **SSH keys:** Copy your keys (e.g. `id_ed25519`, `id_ed25519.pub`) from the old Mac or generate new ones and add the public key to GitHub etc.
- **Secrets:** If `.zshrc` had tokens, set them again (e.g. `gh auth login`) or edit `~/.zshrc`.
- **Computer name:** Edit `os.sh` and change `jakemacx` to your Mac Studio name before running `--scripts`, or run `sudo scutil --set ComputerName "..."` manually.
- **Log out / restart** so OS and shell changes take effect.

## Scripts

| Script              | Purpose |
|---------------------|--------|
| `clone-settings.sh` | Run on source Mac: capture dotfiles, Brewfile, Cursor/VSCode into repo |
| `replicate.sh`      | Run on new Mac: apply cloned config and optionally run setup scripts |
| `init.sh`           | Homebrew, git, node, python, QuickLook, fonts |
| `os.sh`             | macOS defaults (trackpad, Finder, Dock, Safari, etc.) |
| `apps.sh`           | Mac App Store apps and Homebrew casks (Rectangle, Docker, OrbStack, etc.) |
| `zsh.sh`            | Zsh, Oh My Zsh, zplug |
| `zprofile`          | Shell env (PATH, aliases) – symlink or copy to `~/.zprofile` if you use it |

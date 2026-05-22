#!/usr/bin/env bash
# Set up SSH access + `isodora1` shell function to run the Hermes agent
# running on a Hostinger VPS from this Mac. Idempotent — safe to re-run.
#
# Usage:  bash setup-isodora1.sh
#
# Requirements: macOS with ssh, ssh-keygen, pbcopy (all stock).

set -euo pipefail

# ─── Config (edit if pointing at a different VPS) ──────────────────────────
VPS_IP="168.231.125.150"
VPS_HOST_ALIAS="hermes"
ALIAS_NAME="isodora1"
HERMES_IMAGE="ghcr.io/hostinger/hvps-hermes-agent"
KEY_PATH="$HOME/.ssh/id_ed25519"
ZSHRC="$HOME/.zshrc"
SSH_CONFIG="$HOME/.ssh/config"

# ─── Helpers ───────────────────────────────────────────────────────────────
say()   { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
ok()    { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
warn()  { printf "  \033[1;33m!\033[0m %s\n" "$*"; }
fail()  { printf "  \033[1;31m✗\033[0m %s\n" "$*"; exit 1; }

# ─── 1. SSH key ────────────────────────────────────────────────────────────
say "Step 1/5  Ensuring an SSH key exists"
if [ -f "$KEY_PATH" ]; then
  ok "Found existing key at $KEY_PATH (reusing — not overwriting)"
else
  ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$(whoami)-$(hostname -s)" -N ""
  ok "Generated $KEY_PATH"
fi

# ─── 2. Copy public key + prompt for hPanel paste ──────────────────────────
say "Step 2/5  Add public key to Hostinger"
pbcopy < "${KEY_PATH}.pub"
echo
echo "  ┌─ Public key (also on clipboard) ─────────────────────────────────"
sed 's/^/  │ /' "${KEY_PATH}.pub"
echo "  └──────────────────────────────────────────────────────────────────"
echo
echo "  → Open https://hpanel.hostinger.com"
echo "  → VPS → your server → Manage → Settings → SSH keys → Add SSH key"
echo "  → Paste (⌘V) and Save"
echo
read -r -p "  Press Enter once the key is saved in hPanel… "

# ─── 3. SSH config entry ───────────────────────────────────────────────────
say "Step 3/5  Adding '$VPS_HOST_ALIAS' shortcut to ~/.ssh/config"
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"
if grep -q "^Host $VPS_HOST_ALIAS\$" "$SSH_CONFIG"; then
  ok "Host '$VPS_HOST_ALIAS' already present — skipping"
else
  cat >> "$SSH_CONFIG" <<EOF

Host $VPS_HOST_ALIAS
    HostName $VPS_IP
    User root
    IdentityFile $KEY_PATH
EOF
  ok "Added '$VPS_HOST_ALIAS' to ~/.ssh/config"
fi

# ─── 4. Test connection + discover container ──────────────────────────────
say "Step 4/5  Testing SSH and finding the Hermes container"
if ! ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
        -o BatchMode=yes "$VPS_HOST_ALIAS" 'echo OK' >/dev/null 2>&1; then
  fail "SSH connection failed. Did the key get saved correctly in hPanel?"
fi
ok "SSH works"

CONTAINER=$(ssh "$VPS_HOST_ALIAS" \
  "docker ps --filter ancestor=${HERMES_IMAGE}:latest --format '{{.Names}}' | head -1")
if [ -z "$CONTAINER" ]; then
  fail "No running container from $HERMES_IMAGE found on the VPS."
fi
ok "Found container: $CONTAINER"

# ─── 5. Shell function in ~/.zshrc ─────────────────────────────────────────
say "Step 5/5  Adding '$ALIAS_NAME' function to ~/.zshrc"
touch "$ZSHRC"
if grep -qE "^(alias[[:space:]]+|function[[:space:]]+)?${ALIAS_NAME}[[:space:]]*[\(=]" "$ZSHRC"; then
  warn "'$ALIAS_NAME' already defined in ~/.zshrc — leaving as-is"
else
  cat >> "$ZSHRC" <<EOF

# Hermes agent on Hostinger VPS — added by setup-isodora1.sh
# ${ALIAS_NAME}       — YOLO mode (no approval prompts; default)
# ${ALIAS_NAME}-safe  — same agent, prompts before dangerous actions
${ALIAS_NAME}() {
  ssh -t ${VPS_HOST_ALIAS} "docker exec -it ${CONTAINER} hermes --yolo --accept-hooks \$*"
}
${ALIAS_NAME}-safe() {
  ssh -t ${VPS_HOST_ALIAS} "docker exec -it ${CONTAINER} hermes \$*"
}
EOF
  ok "Added ${ALIAS_NAME}() and ${ALIAS_NAME}-safe() to ~/.zshrc"
fi

say "Done"
echo "  Run this in a new terminal (or 'source ~/.zshrc' here):"
echo "    $ALIAS_NAME            # interactive Hermes"
echo "    $ALIAS_NAME status     # subcommand example"
echo "    $ALIAS_NAME --help     # all commands"

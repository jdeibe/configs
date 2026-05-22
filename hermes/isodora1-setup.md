# Set up `isodora1` on a new laptop

The `isodora1` command SSHes into the Hermes VPS and execs the `hermes` CLI inside its Docker container. To run it from another laptop, you need three things: the shell function, an SSH host alias, and an authorized SSH key.

## 1. Add the zsh function

Append to `~/.zshrc` on the new laptop:

```zsh
# Hermes agent on Hostinger VPS (srv1651675) — runs the in-container CLI over SSH
# isodora1       — YOLO mode (no approval prompts; default)
# isodora1-safe  — same agent, prompts before dangerous actions
isodora1() {
  ssh -t hermes "docker exec -it hermes-agent-2cl3-hermes-agent-1 hermes --yolo --accept-hooks $*"
}
isodora1-safe() {
  ssh -t hermes "docker exec -it hermes-agent-2cl3-hermes-agent-1 hermes $*"
}
```

Then reload: `source ~/.zshrc`.

## 2. Add the SSH host alias

Append to `~/.ssh/config` on the new laptop:

```
Host hermes
    HostName 168.231.125.150
    User root
    IdentityFile ~/.ssh/id_ed25519
```

If `~/.ssh/config` doesn't exist yet, create it with `chmod 600 ~/.ssh/config`.

## 3. Authorize an SSH key on the VPS

Pick one of the two options.

### Option A — Copy the existing key (fastest)

From the laptop that already has access:

```sh
scp ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub newlaptop:~/.ssh/
ssh newlaptop "chmod 600 ~/.ssh/id_ed25519"
```

### Option B — Generate a fresh key (better hygiene, recommended)

On the new laptop:

```sh
ssh-keygen -t ed25519
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@168.231.125.150
```

This way, if the new laptop is lost you can revoke just that one key from `~/.ssh/authorized_keys` on the VPS without rotating everywhere.

## 4. Verify

```sh
ssh hermes "docker ps | grep hermes-agent"
```

You should see the `hermes-agent-2cl3-hermes-agent-1` container. Then:

```sh
isodora1
```

should drop you into the Hermes CLI.

## Caveat

The container name `hermes-agent-2cl3-hermes-agent-1` is hardcoded in the function. If the container is ever recreated under a different Docker Compose project name, both `isodora1` and `isodora1-safe` will silently fail with "no such container". Update the function on every laptop if that happens.

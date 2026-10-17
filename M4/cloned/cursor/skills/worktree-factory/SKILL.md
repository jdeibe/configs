---
name: worktree-factory
description: >-
  Manage Git worktrees for parallel agent waves and software factory workflows:
  scan all repositories for worktree status, dirty/unpushed changes, and active
  ports; spawn isolated worktrees in <repo>/.claude/worktrees/<slug> with
  copied .env*.local files and full dependency installs; harvest commits and
  review markdown artifacts from wave branches; and safely prune merged or
  [gone] worktrees after archiving untracked notes. Use when the user asks
  about worktrees, parallel agent waves, cleaning up old branches/worktrees, or
  setting up an isolated checkout.
---

# Worktree Factory

Use the bundled deterministic CLI (`~/.cursor/skills/worktree-factory/scripts/wt.py`) instead of ad-hoc `find` or `git` loops.

## Quick Commands

### 1. Radar (Status across all repos or current repo)

Scan all repos under `~/repos` (plus linked worktrees in `.claude/worktrees/` and `~/.cursor/worktrees/`), active ports (`3000`, `6001`, `6002`, `55421`, etc.), and branch health:

```bash
python3 ~/.cursor/skills/worktree-factory/scripts/wt.py radar
python3 ~/.cursor/skills/worktree-factory/scripts/wt.py radar --only-multi
python3 ~/.cursor/skills/worktree-factory/scripts/wt.py radar --repo "$(pwd)"
```

### 2. Spawn (Create a new repo-local worktree)

Default convention is `<repo>/.claude/worktrees/<slug>` on branch `feat/<slug>` from `origin/main`.
`spawn` fetches `origin`, ensures `.claude/worktrees/` is ignored, copies all gitignored `.env*.local` files from the primary checkout, and runs `pnpm install --prefer-offline` (or `bun install`).

```bash
python3 ~/.cursor/skills/worktree-factory/scripts/wt.py spawn <slug> --repo "$(pwd)"
```

**Never symlink `node_modules`** across worktrees—Next.js / Turbopack resolves the symlink target back to the main checkout and corrupts module resolution.

### 3. Harvest (Inspect or promote a completed agent wave)

Before merging or cherry-picking a wave worktree, inspect its commits ahead of `origin/main` and rescue any untracked review markdown files (e.g. `PRD*-REVIEW-*.md`):

```bash
python3 ~/.cursor/skills/worktree-factory/scripts/wt.py harvest <slug-or-path> --repo "$(pwd)" --collect-docs
```

### 4. Prune (Safe cleanup with artifact rescue)

Always run dry-run first. When `--apply` is passed, `prune` automatically rescues uncommitted diffs (`uncommitted.patch`) and untracked `.md`/`.txt` notes to `~/.cursor/worktree-archives/<timestamp>/` before removing worktrees that have `0` unmerged commits:

```bash
# Dry-run audit across all repos (including ~/.cursor/worktrees waves)
python3 ~/.cursor/skills/worktree-factory/scripts/wt.py prune --include-stale-waves

# Execute safe removal after user confirmation
python3 ~/.cursor/skills/worktree-factory/scripts/wt.py prune --include-stale-waves --apply
```

## Shared Resource Guardrails

Worktrees isolate files and git index, **not** local ports or Docker containers:
1. Check `radar` active ports before starting `pnpm dev:all` or killing ports (`6001`, `6002`, `3000`).
2. Local Supabase (`55421`/`55422`) is shared across all worktrees of a repo. Running `pnpm db:reset` in one worktree wipes local database state for every other worktree.

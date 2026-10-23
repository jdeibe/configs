---
name: disk-cleanup
description: >-
  Free macOS disk space with a safe cleanup script: Homebrew, unused Docker
  images/volumes, pnpm/npm caches, Xcode DerivedData, inactive repo
  node_modules/.next under ~/repos, and regenerable app caches (ShipIt, Codex,
  Playwright, Google). Preserves node_modules for active projects
  (isodora-core, hemlo-platform, platform). Use when the user asks to free
  disk space, clean caches, reclaim storage, or run diskclean / disk cleanup.
---

# Disk Cleanup

Use the bundled script instead of ad-hoc `rm` / `find` loops.

## Command

```bash
# Preview
~/.cursor/skills/disk-cleanup/scripts/cleanup.sh --dry-run

# Apply
~/.cursor/skills/disk-cleanup/scripts/cleanup.sh
```

Shell shortcuts (if installed in `.zshrc`):

```bash
diskclean --dry-run   # preview
diskclean             # apply
```

## What it does

1. `brew cleanup -s` + clear Homebrew download cache  
2. `docker image prune -af` + `docker volume prune -f` (running containers kept)  
3. `pnpm store prune` + `npm cache clean --force`  
4. Clear Xcode DerivedData  
5. Remove `node_modules` and `.next` under `~/repos` except keep-list repos  
6. Clear regenerable caches (Cursor/Windsurf/Slack ShipIt, Codex, Playwright, Google, etc.)  

Reports Container Free Space before and after.

## Keep list (do not delete deps)

- `isodora/isodora-core`
- `ai-sven/hemlo-platform`
- `ai-sven/platform`

Override scan root: `REPOS_ROOT=/path cleanup.sh`

## Agent instructions

1. Prefer running the script over inventing a new cleanup.  
2. For “how much space / preview first”, run with `--dry-run`.  
3. For “clean up / free space”, run without `--dry-run`.  
4. Do not delete `node_modules` from keep-list repos unless the user explicitly asks.  
5. After apply, mention Playwright reinstall (`npx playwright install`) and that inactive repos need reinstall.

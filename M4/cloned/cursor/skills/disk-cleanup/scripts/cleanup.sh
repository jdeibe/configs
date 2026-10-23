#!/usr/bin/env bash
#
# Free disk space: Homebrew, Docker unused images, package caches,
# inactive repo node_modules/.next, and regenerable app caches.
#
# Usage:
#   cleanup.sh              # run cleanup
#   cleanup.sh --dry-run    # preview only
#   cleanup.sh --help
#

set -euo pipefail

DRY_RUN=0
REPOS_ROOT="${REPOS_ROOT:-$HOME/repos}"

# Never delete node_modules/.next under these repo paths (active projects)
KEEP_REPOS=(
  "isodora/isodora-core"
  "ai-sven/hemlo-platform"
  "ai-sven/platform"
)

usage() {
  cat <<'EOF'
Usage: cleanup.sh [--dry-run] [--help]

Frees disk space safely:
  - brew cleanup -s + brew download cache
  - unused Docker images/volumes (keeps running containers)
  - pnpm store prune + npm cache
  - Xcode DerivedData
  - node_modules + .next in inactive repos under ~/repos
  - regenerable caches (ShipIt, Codex, Playwright, Google, etc.)

Active repos kept (node_modules/.next preserved):
  isodora/isodora-core, ai-sven/hemlo-platform, ai-sven/platform

Override repos root with REPOS_ROOT=/path.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

rm_rf() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    return 0
  fi
  local sz
  sz=$(du -sh "$path" 2>/dev/null | awk '{print $1}' || echo "?")
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] rm -rf $path ($sz)"
  else
    rm -rf "$path"
    echo "  removed $path ($sz)"
  fi
}

should_keep_repo_path() {
  local path="$1"
  local keep
  for keep in "${KEEP_REPOS[@]}"; do
    if [[ "$path" == *"/repos/$keep"* ]] || [[ "$path" == *"/repos/$keep" ]]; then
      return 0
    fi
  done
  return 1
}

free_space() {
  diskutil info / 2>/dev/null | awk -F': ' '/Container Free Space/ {print $2; exit}' \
    || df -h /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4 " available"}'
}

echo "=== disk-cleanup $([[ $DRY_RUN -eq 1 ]] && echo '(dry-run)' || echo '(apply)') ==="
echo "Free before: $(free_space)"
echo ""

# --- Homebrew ---
echo ">>> Homebrew"
if command -v brew >/dev/null 2>&1; then
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] brew cleanup -s"
    echo "  [dry-run] clear brew download cache"
  else
    brew cleanup -s || true
    cache="$(brew --cache 2>/dev/null || true)"
    if [[ -n "$cache" && -d "$cache" ]]; then
      rm -rf "${cache:?}"/*
      echo "  cleared brew cache"
    fi
  fi
else
  echo "  brew not found, skip"
fi
echo ""

# --- Docker (unused only; running containers kept) ---
echo ">>> Docker unused images/volumes"
if command -v docker >/dev/null 2>&1; then
  run docker image prune -af || true
  run docker volume prune -f || true
else
  echo "  docker not found, skip"
fi
echo ""

# --- Package managers ---
echo ">>> Package manager caches"
if command -v pnpm >/dev/null 2>&1; then
  run pnpm store prune || true
else
  echo "  pnpm not found, skip store prune"
fi
if command -v npm >/dev/null 2>&1; then
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] npm cache clean --force"
  else
    npm cache clean --force >/dev/null 2>&1 || true
    echo "  npm cache cleaned"
  fi
fi
rm_rf "$HOME/.npm/_cacache"
echo ""

# --- Xcode ---
echo ">>> Xcode DerivedData"
rm_rf "$HOME/Library/Developer/Xcode/DerivedData"
# recreate empty dir so Xcode is happy
if [[ $DRY_RUN -eq 0 ]]; then
  mkdir -p "$HOME/Library/Developer/Xcode/DerivedData"
fi
echo ""

# --- Inactive repo node_modules / .next ---
echo ">>> Inactive repo node_modules and .next (under $REPOS_ROOT)"
if [[ -d "$REPOS_ROOT" ]]; then
  while IFS= read -r -d '' dir; do
    if should_keep_repo_path "$dir"; then
      echo "  keep $dir"
      continue
    fi
    rm_rf "$dir"
  done < <(find "$REPOS_ROOT" \( -type d -name node_modules -o -type d -name .next \) -prune -print0 2>/dev/null)
else
  echo "  $REPOS_ROOT not found, skip"
fi
echo ""

# --- Regenerable app caches ---
echo ">>> App / tool caches"
CACHE="$HOME/Library/Caches"
rm_rf "$CACHE/com.todesktop.230313mzl4w4u92.ShipIt"
rm_rf "$CACHE/com.exafunction.windsurf.ShipIt"
rm_rf "$CACHE/com.tinyspeck.slackmacgap.ShipIt"
rm_rf "$CACHE/com.openai.codex"
rm_rf "$CACHE/claude-cli-nodejs"
rm_rf "$CACHE/com.steipete.codexbar"
rm_rf "$CACHE/ms-playwright"
rm_rf "$CACHE/Google"
rm_rf "$CACHE/pnpm"
echo ""

echo "Free after:  $(free_space)"
if [[ $DRY_RUN -eq 1 ]]; then
  echo ""
  echo "Re-run without --dry-run to apply."
else
  echo ""
  echo "Done. Note: Playwright needs 'npx playwright install' again if you use it."
  echo "Inactive repos need 'pnpm install' (or npm/yarn) before running again."
fi

#!/usr/bin/env python3
"""
worktree-factory helper CLI for Cursor & Claude Code software factory workflows.

Commands:
  radar [--only-multi] [--json]
      Scan ~/repos and ~/.cursor/worktrees for git repositories and linked worktrees.
      Reports branch, upstream status (ahead/behind/gone), dirty/untracked files,
      symlinked node_modules hazards, and whether the branch is merged into main.

  spawn <slug> [--repo <path>] [--branch <branch>] [--base <ref>] [--no-install]
      Create a new worktree at <repo>/.claude/worktrees/<slug> (ensuring .claude/ is
      gitignored), copy gitignored .env*.local files from the primary checkout, and
      run package installation without symlinking node_modules.

  prune [--repo <path>] [--apply] [--archive-dir <dir>]
      Find linked worktrees whose branch is merged into main or whose remote tracking
      branch is [gone]. Rescues untracked .md/.patch/review files and uncommitted diffs
      to an archive directory before removing the worktree (dry-run unless --apply).

  harvest <worktree-path-or-slug> [--repo <path>] [--collect-docs]
      Inspect a wave worktree's commits ahead of main, diffstat, and untracked review
      markdown files; optionally copy untracked *.md artifacts into the main checkout's
      .WaveArchive/ folder and print the exact merge / cherry-pick commands.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

HOME = Path.home()
DEFAULT_SCAN_ROOTS = [HOME / "repos"]
SKIP_DIRS = {
    "node_modules",
    ".pnpm",
    ".next",
    ".turbo",
    "dist",
    "build",
    "DerivedData",
    "SourcePackages",
    "checkouts",
    ".build",
    "Pods",
    "target",
    ".venv",
    "venv",
}


def run_git(cwd: Path, *args: str, check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(cwd), *args],
        text=True,
        capture_output=True,
        check=check,
    )


def find_repo_roots(scan_roots: list[Path]) -> list[Path]:
    seen_common: set[Path] = set()
    primary_roots: list[Path] = []
    for base in scan_roots:
        if not base.exists():
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [
                d
                for d in dirnames
                if d not in SKIP_DIRS and not (d.startswith(".") and d not in {".git", ".claude"})
            ]
            if ".git" in dirnames or ".git" in filenames:
                p = Path(dirpath)
                res = run_git(p, "rev-parse", "--git-common-dir")
                if res.returncode == 0:
                    common = Path(res.stdout.strip())
                    if not common.is_absolute():
                        common = (p / common).resolve()
                    else:
                        common = common.resolve()
                    if common not in seen_common:
                        seen_common.add(common)
                        primary_roots.append(common.parent if common.name == ".git" else p)
                dirnames[:] = [d for d in dirnames if d != ".git"]
    return sorted(primary_roots)


def parse_worktree_list(repo_root: Path) -> list[dict[str, Any]]:
    res = run_git(repo_root, "worktree", "list", "--porcelain")
    if res.returncode != 0:
        return []
    items: list[dict[str, Any]] = []
    current: dict[str, Any] = {}
    for line in res.stdout.splitlines():
        if not line.strip():
            if current:
                items.append(current)
                current = {}
            continue
        if line.startswith("worktree "):
            current["path"] = line[len("worktree ") :].strip()
        elif line.startswith("HEAD "):
            current["head"] = line[len("HEAD ") :].strip()[:8]
        elif line.startswith("branch "):
            ref = line[len("branch ") :].strip()
            current["branch"] = ref.removeprefix("refs/heads/")
        elif line == "detached":
            current["branch"] = "(detached)"
        elif line.startswith("prunable "):
            current["prunable"] = line[len("prunable ") :].strip()
    if current:
        items.append(current)
    return items


def inspect_worktree(wt: dict[str, Any], primary_root: Path, default_branch: str) -> dict[str, Any]:
    p = Path(wt["path"])
    info = {
        "path": str(p),
        "is_primary": p.resolve() == primary_root.resolve(),
        "head": wt.get("head", ""),
        "branch": wt.get("branch", "(detached)"),
        "exists": p.exists(),
        "prunable": wt.get("prunable"),
        "upstream": None,
        "ahead": 0,
        "behind": 0,
        "gone": False,
        "modified": 0,
        "staged": 0,
        "untracked": 0,
        "untracked_notes": [],
        "merged_into_main": False,
        "commits_ahead_of_main": 0,
        "symlink_node_modules": False,
    }
    if not p.exists():
        return info

    nm = p / "node_modules"
    if nm.is_symlink():
        info["symlink_node_modules"] = True

    st = run_git(p, "status", "--porcelain=v1", "-b")
    if st.returncode == 0:
        lines = st.stdout.splitlines()
        if lines and lines[0].startswith("## "):
            header = lines[0][3:]
            if "..." in header:
                _, rest = header.split("...", 1)
                if " [" in rest:
                    up, bracket = rest.split(" [", 1)
                    info["upstream"] = up.strip()
                    bracket = bracket.rstrip("]")
                    if "gone" in bracket:
                        info["gone"] = True
                    m_ahead = re.search(r"ahead (\d+)", bracket)
                    m_behind = re.search(r"behind (\d+)", bracket)
                    if m_ahead:
                        info["ahead"] = int(m_ahead.group(1))
                    if m_behind:
                        info["behind"] = int(m_behind.group(1))
                else:
                    info["upstream"] = rest.strip()
        for line in lines[1:]:
            if line.startswith("?? "):
                info["untracked"] += 1
                rel = line[3:].strip()
                if rel.endswith((".md", ".txt", ".patch", ".diff")):
                    info["untracked_notes"].append(rel)
            else:
                if len(line) >= 2:
                    if line[0] not in (" ", "?"):
                        info["staged"] += 1
                    if line[1] not in (" ", "?"):
                        info["modified"] += 1

    branch = info["branch"]
    if branch not in ("(detached)", default_branch, "main", "master"):
        base_ref = f"origin/{default_branch}"
        chk = run_git(p, "rev-parse", "--verify", base_ref)
        if chk.returncode != 0:
            base_ref = default_branch
        cnt = run_git(p, "rev-list", "--count", f"{base_ref}..HEAD")
        if cnt.returncode == 0 and cnt.stdout.strip().isdigit():
            info["commits_ahead_of_main"] = int(cnt.stdout.strip())
            info["merged_into_main"] = info["commits_ahead_of_main"] == 0

    return info


def detect_default_branch(repo_root: Path) -> str:
    res = run_git(repo_root, "symbolic-ref", "refs/remotes/origin/HEAD")
    if res.returncode == 0:
        return res.stdout.strip().removeprefix("refs/remotes/origin/")
    return "main"


def detect_listening_ports() -> dict[int, dict[str, str]]:
    ports: dict[int, dict[str, str]] = {}
    for port in (3000, 3001, 5173, 6001, 6002, 8000, 8080, 55421, 55422):
        res = subprocess.run(
            ["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN", "-Fpcn"],
            text=True,
            capture_output=True,
        )
        if res.returncode == 0 and res.stdout.strip():
            pid = ""
            cmd = ""
            for line in res.stdout.splitlines():
                if line.startswith("p") and not pid:
                    pid = line[1:]
                elif line.startswith("c") and not cmd:
                    cmd = line[1:]
            cwd = ""
            if pid:
                cwd_res = subprocess.run(
                    ["lsof", "-a", "-p", pid, "-d", "cwd", "-Fn"],
                    text=True,
                    capture_output=True,
                )
                for line in cwd_res.stdout.splitlines():
                    if line.startswith("n"):
                        cwd = line[1:]
            ports[port] = {"pid": pid, "cmd": cmd, "cwd": cwd}
    return ports


def cmd_radar(args: argparse.Namespace) -> int:
    roots = [Path(args.repo).resolve()] if args.repo else find_repo_roots(DEFAULT_SCAN_ROOTS)
    report: list[dict[str, Any]] = []
    total_wt = 0

    for root in roots:
        default_branch = detect_default_branch(root)
        raw_wts = parse_worktree_list(root)
        if not raw_wts:
            continue
        if args.only_multi and len(raw_wts) <= 1:
            continue
        inspected = [inspect_worktree(w, root, default_branch) for w in raw_wts]
        total_wt += len(inspected)
        report.append(
            {
                "repo": str(root),
                "name": f"{root.parent.name}/{root.name}",
                "default_branch": default_branch,
                "worktree_count": len(inspected),
                "worktrees": inspected,
            }
        )

    ports = detect_listening_ports()

    if args.json:
        print(json.dumps({"repos": report, "total_worktrees": total_wt, "ports": ports}, indent=2))
        return 0

    print(f"Worktree Radar — {len(report)} repos shown ({total_wt} worktrees)")
    if ports:
        port_parts = [
            f":{p} ({v['cmd']} pid={v['pid']} cwd={v['cwd'] or '?'})"
            for p, v in sorted(ports.items())
        ]
        print("Active ports: " + " | ".join(port_parts))
    print("-" * 88)

    for r in report:
        multi_tag = f" [{r['worktree_count']} worktrees]" if r["worktree_count"] > 1 else ""
        print(f"\n{r['name']} ({r['repo']}){multi_tag}")
        for w in r["worktrees"]:
            tags: list[str] = []
            if w["is_primary"]:
                tags.append("primary")
            if not w["exists"]:
                tags.append("MISSING-DIR")
            if w["gone"]:
                tags.append("upstream:GONE")
            if w["ahead"]:
                tags.append(f"ahead:{w['ahead']}")
            if w["behind"]:
                tags.append(f"behind:{w['behind']}")
            if w["staged"] or w["modified"]:
                tags.append(f"dirty:{w['staged']}s/{w['modified']}m")
            if w["untracked"]:
                tags.append(f"untracked:{w['untracked']}")
            if w["untracked_notes"]:
                tags.append(f"notes:{','.join(w['untracked_notes'][:2])}")
            if not w["is_primary"] and w["merged_into_main"] and not (w["staged"] or w["modified"]):
                tags.append("MERGED/0-ahead")
            elif not w["is_primary"] and w["commits_ahead_of_main"] > 0:
                tags.append(f"branch-ahead:{w['commits_ahead_of_main']}")
            if w["symlink_node_modules"]:
                tags.append("WARN:symlink-node_modules")

            tag_str = "  [" + ", ".join(tags) + "]" if tags else "  [clean]"
            print(f"  - {w['branch']:<32} {w['head']}  {w['path']}{tag_str}")

    return 0


def ensure_claude_ignored(repo_root: Path) -> None:
    exclude = repo_root / ".git" / "info" / "exclude"
    gitignore = repo_root / ".gitignore"
    pattern = ".claude/worktrees/"
    if gitignore.exists() and pattern in gitignore.read_text(errors="ignore"):
        return
    if exclude.exists():
        txt = exclude.read_text(errors="ignore")
        if ".claude" not in txt:
            exclude.write_text(txt.rstrip() + f"\n{pattern}\n")


def copy_env_files(primary_root: Path, target_wt: Path) -> list[str]:
    copied: list[str] = []
    for dirpath, dirnames, filenames in os.walk(primary_root):
        rel_dir = Path(dirpath).relative_to(primary_root)
        if any(part in SKIP_DIRS or part in {".git", ".claude"} for part in rel_dir.parts):
            dirnames[:] = []
            continue
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and d not in {".git", ".claude"}]
        for fname in filenames:
            if fname.startswith(".env") and (fname.endswith(".local") or fname == ".env"):
                src = Path(dirpath) / fname
                dst = target_wt / rel_dir / fname
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
                copied.append(str(rel_dir / fname))
    return copied


def cmd_spawn(args: argparse.Namespace) -> int:
    repo_root = Path(args.repo or os.getcwd()).resolve()
    top = run_git(repo_root, "rev-parse", "--git-common-dir")
    if top.returncode != 0:
        print(f"Error: {repo_root} is not inside a git repository", file=sys.stderr)
        return 1
    common = Path(top.stdout.strip())
    if not common.is_absolute():
        common = (repo_root / common).resolve()
    primary_root = common.parent if common.name == ".git" else repo_root

    slug = re.sub(r"[^a-zA-Z0-9._-]+", "-", args.slug.strip()).strip("-")
    branch = args.branch or f"feat/{slug}"
    base = args.base or f"origin/{detect_default_branch(primary_root)}"

    run_git(primary_root, "fetch", "origin", "--prune")
    ensure_claude_ignored(primary_root)

    wt_path = primary_root / ".claude" / "worktrees" / slug
    if wt_path.exists():
        print(f"Error: worktree path already exists: {wt_path}", file=sys.stderr)
        return 1
    wt_path.parent.mkdir(parents=True, exist_ok=True)

    branch_exists = run_git(primary_root, "show-ref", "--verify", f"refs/heads/{branch}").returncode == 0
    if branch_exists:
        res = run_git(primary_root, "worktree", "add", str(wt_path), branch)
    else:
        res = run_git(primary_root, "worktree", "add", "-b", branch, str(wt_path), base)

    if res.returncode != 0:
        print(res.stderr, file=sys.stderr)
        return res.returncode

    copied_envs = copy_env_files(primary_root, wt_path)

    installed = False
    if not args.no_install:
        if (wt_path / "pnpm-lock.yaml").exists():
            subprocess.run(["pnpm", "install", "--prefer-offline"], cwd=wt_path, check=False)
            installed = True
        elif (wt_path / "bun.lock").exists() or (wt_path / "bun.lockb").exists():
            subprocess.run(["bun", "install"], cwd=wt_path, check=False)
            installed = True

    print(
        json.dumps(
            {
                "worktree": str(wt_path),
                "branch": branch,
                "base": base,
                "copied_env_files": copied_envs,
                "dependencies_installed": installed,
            },
            indent=2,
        )
    )
    return 0


def cmd_prune(args: argparse.Namespace) -> int:
    roots = [Path(args.repo).resolve()] if args.repo else find_repo_roots(DEFAULT_SCAN_ROOTS)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    archive_base = Path(args.archive_dir or (HOME / ".cursor" / "worktree-archives" / stamp))

    candidates: list[tuple[Path, dict[str, Any], str]] = []
    for root in roots:
        default_branch = detect_default_branch(root)
        raw_wts = parse_worktree_list(root)
        if len(raw_wts) <= 1:
            continue
        for raw in raw_wts:
            w = inspect_worktree(raw, root, default_branch)
            if w["is_primary"]:
                continue
            reasons: list[str] = []
            if not w["exists"]:
                reasons.append("directory missing")
            if w["gone"]:
                reasons.append("remote branch [gone]")
            if w["merged_into_main"] and w["ahead"] == 0:
                reasons.append("0 commits ahead of main")
            if args.include_stale_waves and "/.cursor/worktrees/" in w["path"]:
                reasons.append("cursor wave worktree")
            if reasons:
                candidates.append((root, w, ", ".join(reasons)))

    if not candidates:
        print("No prunable worktrees found.")
        return 0

    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"[{mode}] Found {len(candidates)} worktrees eligible for cleanup:\n")

    for root, w, reason in candidates:
        wt_path = Path(w["path"])
        slug = wt_path.name
        repo_slug = f"{root.parent.name}__{root.name}"
        dirty_bits = []
        if w["staged"] or w["modified"]:
            dirty_bits.append(f"{w['staged']} staged / {w['modified']} modified")
        if w["untracked"]:
            dirty_bits.append(f"{w['untracked']} untracked")
        if w["untracked_notes"]:
            dirty_bits.append(f"notes: {', '.join(w['untracked_notes'])}")
        if w["commits_ahead_of_main"] > 0:
            dirty_bits.append(f"WARNING: {w['commits_ahead_of_main']} unmerged commits")

        safety = "SAFE" if w["commits_ahead_of_main"] == 0 else "NEEDS-REVIEW (unmerged commits)"
        print(f"  * {wt_path}")
        print(f"    branch: {w['branch']} ({w['head']}) | reason: {reason} | {safety}")
        if dirty_bits:
            print(f"    rescue before remove: {'; '.join(dirty_bits)}")

        if args.apply and w["commits_ahead_of_main"] == 0:
            dest = archive_base / repo_slug / f"{slug}-{w['head']}"
            if wt_path.exists() and (w["staged"] or w["modified"] or w["untracked_notes"]):
                dest.mkdir(parents=True, exist_ok=True)
                diff = run_git(wt_path, "diff", "HEAD")
                if diff.stdout.strip():
                    (dest / "uncommitted.patch").write_text(diff.stdout)
                for note in w["untracked_notes"]:
                    src_note = wt_path / note
                    if src_note.is_file():
                        target_note = dest / note
                        target_note.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(src_note, target_note)
                print(f"    -> rescued artifacts to {dest}")

            rm = run_git(root, "worktree", "remove", "--force", str(wt_path))
            if rm.returncode == 0:
                print("    -> removed worktree")
            else:
                print(f"    -> failed to remove: {rm.stderr.strip()}")

    if args.apply:
        for root in {r for r, _, _ in candidates}:
            run_git(root, "worktree", "prune")
    else:
        print("\nRe-run with --apply to archive rescued notes/patches and remove SAFE worktrees.")
    return 0


def cmd_harvest(args: argparse.Namespace) -> int:
    repo_root = Path(args.repo or os.getcwd()).resolve()
    target = Path(args.target)
    if not target.exists():
        candidate = repo_root / ".claude" / "worktrees" / args.target
        if candidate.exists():
            target = candidate
    target = target.resolve()
    if not target.exists():
        print(f"Error: worktree not found: {target}", file=sys.stderr)
        return 1

    default_branch = detect_default_branch(repo_root)
    info = inspect_worktree({"path": str(target), "head": "", "branch": ""}, repo_root, default_branch)
    br = run_git(target, "rev-parse", "--abbrev-ref", "HEAD")
    branch = br.stdout.strip() if br.returncode == 0 else "(detached)"
    log = run_git(target, "log", "--oneline", f"origin/{default_branch}..HEAD")
    stat = run_git(target, "diff", "--stat", f"origin/{default_branch}...HEAD")

    print(f"Harvest inspection for: {target}")
    print(f"Branch: {branch}")
    print(f"Dirty: {info['staged']} staged, {info['modified']} modified, {info['untracked']} untracked")
    if info["untracked_notes"]:
        print(f"Untracked docs/notes: {', '.join(info['untracked_notes'])}")
    print("\nCommits ahead of origin/" + default_branch + ":")
    print(log.stdout.strip() or "  (none)")
    print("\nDiffstat:")
    print(stat.stdout.strip() or "  (none)")

    if args.collect_docs and info["untracked_notes"]:
        dest_dir = repo_root / ".claude" / "harvested-notes" / target.name
        dest_dir.mkdir(parents=True, exist_ok=True)
        for note in info["untracked_notes"]:
            src = target / note
            if src.is_file():
                dst = dest_dir / Path(note).name
                shutil.copy2(src, dst)
                print(f"Copied {note} -> {dst}")

    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Worktree Factory CLI")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_radar = sub.add_parser("radar", help="Scan all repos and worktrees")
    p_radar.add_argument("--repo", help="Single repo path to inspect")
    p_radar.add_argument("--only-multi", action="store_true", help="Only show repos with >1 worktree")
    p_radar.add_argument("--json", action="store_true", help="Output JSON")
    p_radar.set_defaults(func=cmd_radar)

    p_spawn = sub.add_parser("spawn", help="Create and bootstrap a repo-local worktree")
    p_spawn.add_argument("slug", help="Short slug for the worktree directory and branch")
    p_spawn.add_argument("--repo", help="Repo root (defaults to cwd)")
    p_spawn.add_argument("--branch", help="Branch name (defaults to feat/<slug>)")
    p_spawn.add_argument("--base", help="Base ref (defaults to origin/main)")
    p_spawn.add_argument("--no-install", action="store_true", help="Skip pnpm/bun install")
    p_spawn.set_defaults(func=cmd_spawn)

    p_prune = sub.add_parser("prune", help="Audit and clean up merged or [gone] worktrees")
    p_prune.add_argument("--repo", help="Single repo path")
    p_prune.add_argument("--include-stale-waves", action="store_true", help="Also inspect ~/.cursor/worktrees waves")
    p_prune.add_argument("--archive-dir", help="Where to rescue untracked notes and diffs")
    p_prune.add_argument("--apply", action="store_true", help="Actually remove safe worktrees after rescuing notes")
    p_prune.set_defaults(func=cmd_prune)

    p_harvest = sub.add_parser("harvest", help="Inspect commits & rescue review docs from a wave worktree")
    p_harvest.add_argument("target", help="Worktree path or slug under .claude/worktrees/<slug>")
    p_harvest.add_argument("--repo", help="Primary repo path")
    p_harvest.add_argument("--collect-docs", action="store_true", help="Copy untracked .md files to .claude/harvested-notes/")
    p_harvest.set_defaults(func=cmd_harvest)

    return p


if __name__ == "__main__":
    parser = build_parser()
    ns = parser.parse_args()
    sys.exit(ns.func(ns))

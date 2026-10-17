---
name: explain-pr
description: >-
  Explains a GitHub pull request by reading the full files on the PR head,
  not only the diff hunks. Use when the user invokes /explain-pr with a pull
  request number or GitHub pull request URL and wants to understand what the
  PR changes and why, without editing anything.
disable-model-invocation: true
---

# Explain a pull request

The user passes a pull request number. Read the code and explain it. Do not edit anything.

## Input

Take the pull request from the user message:

- A number: `1070`, `#1070`, or `PR 1070`
- A GitHub URL: `https://github.com/<owner>/<repo>/pull/1070`

If neither is present, ask for the PR number and stop. Do not guess a number from the screen, the branch name, or an earlier conversation.

## Read the code

Stay on the current branch. Do not checkout, commit, push, stash, or modify files.

1. Load the pull request from the repo that is open:

```bash
gh pr view <number> --json title,body,baseRefName,headRefName,headRefOid,files,url,additions,deletions
```

2. Fetch the head without checking it out:

```bash
git fetch origin pull/<number>/head
```

3. Diff that head against the PR base:

```bash
git diff origin/<baseRefName>...FETCH_HEAD
```

4. For every changed file, read the full file at the PR head, not the hunk:

```bash
git show FETCH_HEAD:<path>
```

5. For each changed function, type, or export, search that same commit for callers the diff does not touch:

```bash
git grep -n <symbol> FETCH_HEAD
```

If `git show` fails because the path was deleted, say the file was removed and read it from the base ref instead. If `gh` or `git fetch` fails, report the error and stop. Do not fall back to the GitHub files-changed page as the only source.

## Answer

Answer these questions, in this order. Keep the wording. Put the PR number where `1070` is:

This branch is the head of GitHub PR 1070. Read the full files, not only the diff hunks.

1. In one short paragraph, what does this PR change and why?
2. Then go file by file. For each file: what changed, what the surrounding code does, and what a reviewer should verify.
3. Call out anything the diff hides because it lives in an unchanged caller.
Do not edit anything.

Use the file path as the heading for each file in step 2. Quote a short snippet from the full file when it makes the change clearer. In step 3, name the unchanged caller and the behavior that is now different.

Do not edit anything.

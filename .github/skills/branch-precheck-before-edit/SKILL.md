---
name: branch-precheck-before-edit
description: Ensure branch safety before making edits. If on main, update from remote and create/switch to an issue/noissue branch using defaults unless the user explicitly specifies a base.
---

# Branch Precheck Before Editing

Use this skill before any code or documentation edits.

## Goal

Prevent accidental edits on `main`, keep new branches based on an up-to-date base, and enforce branch naming rules.

## Required Branch Rules

- If issue exists: `issue-<number>-<short-topic>`
- If issue does not exist: `noissue-<short-topic>`

## Base Selection Inputs

When creating a branch from `main`, use these defaults unless the user explicitly provides different values:

- `base_branch` (default: `main`)
- `base_commit` (optional; commit hash, tag, or other valid rev)

Behavior:

- Do not ask for an issue number, `base_branch`, or `base_commit` as routine branch setup.
- Use an issue number already provided in the task context; otherwise use a `noissue-*` branch.
- If `base_commit` is provided, create the branch from that commit/revision.
- If `base_commit` is omitted, create the branch from `origin/<base_branch>` after updating local refs.

## Execution Steps

1. Check current branch and status.

```bash
git status --short --branch
git branch --show-current
git remote -v
```

2. If current branch is not `main`, continue work on current branch.

3. If current branch is `main`:

- Use the issue number from the task context if available; otherwise select `noissue-*` without asking.
- Use `base_branch=main` unless the user explicitly specifies another branch.
- Leave `base_commit` empty unless the user explicitly specifies a revision.
- Update local refs from remote before branch creation.

```bash
git fetch --prune origin

if [[ "$base_branch" == "main" && -z "$base_commit" ]]; then
	git switch main
	git pull --ff-only origin main
fi
```

- Resolve base reference:
  - If `base_commit` is set: use `base_ref=<base_commit>`.
  - Else: use `base_ref=origin/<base_branch>`.
- If an issue number is available, create/switch `issue-<number>-<short-topic>` from `base_ref`.
- Otherwise, create/switch `noissue-<short-topic>` from `base_ref`.

Example:

```bash
base_branch="main"
base_commit=""
base_ref="origin/${base_branch}"

git switch -c issue-123-update-readme "$base_ref"
# or
git switch -c noissue-update-readme "$base_ref"
```

Example with explicit commit:

```bash
base_commit="abc1234"
git switch -c noissue-update-readme "$base_commit"
```

If the target branch already exists:

```bash
git switch <branch-name>
```

4. Show final branch and status.

```bash
git status --short --branch
git branch --show-current
git log --oneline -n 1
```

## Safety Rules

- Do not edit files before this check completes.
- Do not force-switch away from uncommitted work without explicit user approval.
- Do not rename existing branches automatically.
- Prefer `git pull --ff-only` to avoid unintended merge commits during precheck.
- If `base_commit` is invalid or unreachable, stop and ask for a different base.

## Output Requirements

Always report:

- Initial branch name
- Final branch name
- Whether branch was created or switched
- Selected `base_branch`
- Selected `base_commit` (or "none")
- Final base reference used for branch creation

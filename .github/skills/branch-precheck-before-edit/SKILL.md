---
name: branch-precheck-before-edit
description: Ensure branch safety before making edits. If on main, create/switch to an issue/noissue branch first.
---

# Branch Precheck Before Editing

Use this skill before any code or documentation edits.

## Goal

Prevent accidental edits on `main` and enforce branch naming rules.

## Required Branch Rules

- If issue exists: `issue-<number>-<short-topic>`
- If issue does not exist: `noissue-<short-topic>`

## Execution Steps

1. Check current branch and status.

```bash
git status --short --branch
git branch --show-current
```

2. If current branch is not `main`, continue work on current branch.

3. If current branch is `main`:
- Ask whether an issue number exists.
- If yes, create/switch `issue-<number>-<short-topic>`.
- If no, create/switch `noissue-<short-topic>`.

Example:

```bash
git switch -c issue-123-update-readme
# or
git switch -c noissue-update-readme
```

If the target branch already exists:

```bash
git switch <branch-name>
```

4. Show final branch and status.

```bash
git status --short --branch
git branch --show-current
```

## Safety Rules

- Do not edit files before this check completes.
- Do not force-switch away from uncommitted work without explicit user approval.
- Do not rename existing branches automatically.

## Output Requirements

Always report:

- Initial branch name
- Final branch name
- Whether branch was created or switched

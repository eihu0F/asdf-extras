---
name: project-rules
description: "Use at the start of every task in this repository, before editing files or answering questions about it. Defines language rules, the branch and PR workflow, shell and lint expectations, and asdf-extras behavior rules, and points to the other project skills."
---

# Project Rules

## Language

- Respond to the user in the user's language.
- Keep all project artifacts in English unless the user explicitly requests otherwise. This includes source code, comments, documentation, commit messages, and PR text.

## Branch and PR Workflow

- Direct pushes to `main` are not allowed. Create a branch first, then open a pull request.
- Branch names: `issue-<number>-<short-topic>` with an issue, `noissue-<short-topic>` without one.
- Before editing files, use the `branch-precheck-before-edit` skill.
- For commit messages, PR titles, and opening a PR, use the `commit-and-pr` skill.
- For releases, use the `release-by-tag-and-page` skill.

## Shell Scripts, Formatting, and Linting

- Follow `.editorconfig` as the minimum baseline for whitespace, indentation, and line endings.
- When editing shell scripts (including extensionless files under `bin/`, `lib/`, `libexec/`, and `scripts/`), use the `shell-implementation` skill.
- Before finishing shell-related changes, use the `shell-lint` skill to run the pinned `shellcheck` and `shfmt` checks.

## asdf-extras Behavior Rules

- Keep command behavior aligned with the current README and command-help output.
- `asdf-extras update` with no arguments is equivalent to `asdf-extras update --all`.
- Do not infer `--all` merely because a plugin argument is omitted when target or scope options are provided; follow the command's explicit target and scope semantics.
- Bulk version updates must continue when a plugin cannot resolve `latest`; skip it with a clear warning.
- Do not introduce behavior that only passes `asdf plugin test` but breaks normal user workflows.

## Adding or Changing Skills

- Use the `add-skill` skill. `.agents/skills/` is the source of truth; edit skills only there. When the edits are done, copy them to `.claude/skills/` (a plain copy, never edited directly).

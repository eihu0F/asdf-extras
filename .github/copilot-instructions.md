# Copilot Project Instructions

Use the following project-level rules when working in this repository.

## Language Rules

- Respond to the user in the user's language.
- Keep all project artifacts in English unless the user explicitly requests otherwise.
  - This includes source code, comments, documentation, commit messages, and PR text.

## Commit Message Definition

Use this commit message format:

```text
<type>: <subject>

* <description item 1>
* <description item 2>
```

Requirements:

- `subject` must be short and action-oriented.
- `description` items must describe user-visible impact.
- Allowed `type` values:
  - `feat`
  - `fix`
  - `docs`
  - `style`
  - `refactor`
  - `test`
  - `chore`

## Release Versioning Rules

- This repository uses `release-please` with Conventional Commits for version bumps.
- Releasable commit intent:
  - `fix:` => patch bump
  - `feat:` => minor bump
  - `feat!:` / `fix!:` (or `BREAKING CHANGE`) => major bump
- Non-breaking `docs`, `style`, `test`, `chore`, and `refactor` commits should not be used when the intent is to trigger a release bump.
- Runtime release scope is limited to installed asdf-extras runtime paths:
  - `bin/**`
  - `lib/**`
  - `libexec/**`
  - `init/**`
- Changes only outside runtime scope should use non-releasable commit types unless an intentional release is required.

## Pull Request Title Rules

- PR titles must follow Conventional Commits style: `<type>: <subject>`.
- Keep the subject short and action-oriented.
- Use one of these `type` values in PR titles:
  - `build`
  - `chore`
  - `ci`
  - `docs`
  - `feat`
  - `fix`
  - `perf`
  - `refactor`
  - `revert`
  - `style`
  - `test`

## Branch and PR Workflow Rules

- Direct pushes to `main` are not allowed for normal development changes.
- Always create a feature/fix branch first, then open a pull request.
- Pull request merge is required before changes reach `main`.
- Branch names must follow one of these patterns:
  - With issue: `issue-<number>-<short-topic>` (example: `issue-123-install-parent-option`)
  - Without issue: `noissue-<short-topic>` (example: `noissue-update-contributing-guide`)
  - Branch names do not need a commit/PR type prefix.
- Before starting edits, run the skill `branch-precheck-before-edit`.
- If current branch is `main`, create/switch to an `issue-*` or `noissue-*` branch before modifying files.
- Before opening a PR, run local validation commands documented in `contributing.md`.
- Before creating a PR, read `.github/PULL_REQUEST_TEMPLATE.md` and use its headings and checklist. Fill in every section; write `None` for no related issue, report actual test commands/results, and mark checklist boxes only when true.
- Use the `create-pull-request` skill when opening a PR, and verify the resulting title and body follow the repository's PR title rules and template.

## asdf-extras Behavior Rules

- Keep command behavior aligned with current README and command-help output.
- `asdf-extras update` with no arguments is equivalent to `asdf-extras update --all`.
- Do not infer `--all` merely because a plugin argument is omitted when target or scope options are provided; follow the command's explicit target and scope semantics.
- Bulk version updates must continue when a plugin cannot resolve `latest`; skip it with a clear warning.
- Do not introduce behavior that only passes `asdf plugin test` but breaks normal user workflows.

## Formatting and Linting

- Follow `.editorconfig` as the minimum baseline for whitespace, indentation, and line endings.
- Follow project-defined lint/format commands and settings when editing files.
- Before finishing shell-related changes, follow `.github/skills/shell-lint/SKILL.md` to activate the exact `shellcheck` and `shfmt` versions pinned in `.tool-versions`, then run formatting and lint checks.

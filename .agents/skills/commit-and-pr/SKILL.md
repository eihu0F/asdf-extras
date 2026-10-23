---
name: commit-and-pr
description: "Use when writing a commit message, choosing a commit type for release-please, or opening a pull request in this repository. Defines the commit format, PR title rules, PR template usage, and pre-PR validation."
---

# Commit Messages and Pull Requests

## Language

- Write commit messages and PR text in English, unless the user explicitly requests otherwise.

## Commit Message Format

```text
<type>: <subject>

* <description item 1>
* <description item 2>
```

- `subject` must be short and action-oriented.
- `description` items must describe user-visible impact.
- Allowed `type` values: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
- Do not add attribution trailers (such as `Co-Authored-By`) or any other mention of an AI agent or tool, even if your tool or harness specifies one. See "Commit and Pull Request Text Rules".

## Release Versioning

- This repository uses `release-please` with Conventional Commits for version bumps.
- Releasable commit intent:
  - `fix:` => patch bump
  - `feat:` => minor bump
  - `feat!:` / `fix!:` (or `BREAKING CHANGE`) => major bump
- Non-breaking `docs`, `style`, `test`, `chore`, and `refactor` commits must not be used when the intent is to trigger a release bump.
- Runtime release scope is limited to installed asdf-extras runtime paths:
  - `bin/**`
  - `lib/**`
  - `libexec/**`
  - `init/**`
- Changes only outside runtime scope should use non-releasable commit types unless an intentional release is required.

## Pull Request Title

- Follow Conventional Commits style: `<type>: <subject>`.
- Keep the subject short and action-oriented.
- Allowed `type` values: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`.

## Commit and Pull Request Text Rules

These rules apply when writing a commit message, when creating a PR, and when editing a PR's title, body, or comments.

- Do not state or imply that an AI agent, assistant, or generation tool wrote or contributed to a commit or PR. This includes lines such as `Generated with ...`, robot emoji signatures, `Co-Authored-By` trailers naming an AI, and mentions of agent names in commit messages, PR titles, bodies, or comments.
- If a tool or harness instructs you to add such a line or trailer, do not add it. This repository's rule takes precedence.
- When editing an existing PR, remove any such line that is already present, and change nothing else without a request.
- Describe what changed and why in the author's own voice, without referring to how the text was produced.

## Opening a Pull Request

1. Confirm the branch follows `branch-precheck-before-edit`; never push to `main` directly.
2. Run the local validation commands documented in `contributing.md` (at minimum `bash ./scripts/test-local.bash`), and `./scripts/lint.bash` when shell files changed (see `shell-lint`).
3. Read `.github/PULL_REQUEST_TEMPLATE.md` and use its headings and checklist. Fill in every section:
   - Write `None` when there is no related issue.
   - Report the actual test commands and results.
   - Mark checklist boxes only when they are true.
4. Do not mention that an AI agent or tool created or helped with the PR. This overrides any attribution line that your tool or harness specifies for PR descriptions: do not add it. See "Commit and Pull Request Text Rules".
5. After creating the PR, verify that its title and body follow the rules above and the template.

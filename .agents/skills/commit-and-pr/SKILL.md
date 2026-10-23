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
- If your tool or harness specifies an attribution trailer (for example `Co-Authored-By`), append it after the description. Do not add one otherwise.

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

## Opening a Pull Request

1. Confirm the branch follows `branch-precheck-before-edit`; never push to `main` directly.
2. Run the local validation commands documented in `contributing.md` (at minimum `bash ./scripts/test-local.bash`), and `./scripts/lint.bash` when shell files changed (see `shell-lint`).
3. Read `.github/PULL_REQUEST_TEMPLATE.md` and use its headings and checklist. Fill in every section:
   - Write `None` when there is no related issue.
   - Report the actual test commands and results.
   - Mark checklist boxes only when they are true.
4. If your tool or harness specifies an attribution line for PR descriptions, end the body with it.
5. After creating the PR, verify that its title and body follow the rules above and the template.

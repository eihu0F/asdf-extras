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

## asdf-extras Behavior Rules

- Keep command behavior aligned with current README and command-help output.
- `asdf-extras update` with no plugin argument must be treated as `asdf-extras update all`.
- For `update all`, continue processing even if a plugin cannot resolve `latest`; skip with a clear warning.
- Do not introduce behavior that only passes `asdf plugin test` but breaks normal user workflows.

## Formatting and Linting

- Follow `.editorconfig` as the minimum baseline for whitespace, indentation, and line endings.
- Follow project-defined lint/format commands and settings when editing files.
- Before finishing shell-related changes, run:
  - `./scripts/format.bash`
  - `./scripts/lint.bash`

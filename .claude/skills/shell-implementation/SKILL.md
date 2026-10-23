---
name: shell-implementation
description: "Use when creating or editing shell scripts in this repository, including extensionless scripts under bin/, lib/, libexec/, and scripts/. Defines safety, style, and change-scope rules."
---

# Shell Implementation Rules

## Safety

- Preserve existing shebang lines.
- Use `set -euo pipefail` unless there is a clear compatibility reason not to.
- Quote variable expansions by default (for example, `"$var"`).
- Validate target paths before destructive operations (`rm -rf`, `mv`, `cp`).

## Style and Syntax

- Avoid introducing shell-specific syntax unless the target shell requires it.
- For POSIX-oriented scripts, keep syntax POSIX-compliant (`[ ... ]`, portable flags, portable built-ins).
- For Bash-only scripts, Bash features are allowed, but do not require them unnecessarily.
- Use `$(...)` instead of backticks for command substitution.
- Avoid `eval` unless unavoidable; validate all inputs when used.
- Keep dependencies minimal and check tool availability when required.

## Lint and Format

- Follow the project-defined linter/formatter settings and commands.
- Use `scripts/lint.bash` as the source of truth for shell lint/format checks.
- Before running formatter or linter, follow the `shell-lint` skill to activate the exact tool versions pinned in `.tool-versions`.
- Do not introduce style that conflicts with ShellCheck or shfmt rules used by this project.

## Change Scope

- Keep edits minimal and focused.
- Avoid broad rewrites and unrelated formatting changes.
- Preserve current behavior unless a change is explicitly required.

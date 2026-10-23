---
name: shell-lint
description: "Use when editing shell scripts or running shell formatting and lint checks. Prepare the repository's tools with asdf and run the project checks."
---

# Shell Formatting and Linting

From the repository root, run:

```bash
asdf install &&
asdf exec shellcheck --version &&
asdf exec shfmt --version &&
./scripts/format.bash &&
./scripts/lint.bash
```

Let asdf select versions; do not read or copy version numbers manually.
Only if shims are missing, add `"${ASDF_DATA_DIR:-$HOME/.asdf}/shims"` to
`PATH` and run `asdf reshim`, then retry.
Report failures explicitly; never skip a check or infer success from the lint
script's exit code alone if its output contains errors. Review the diff after
formatting and preserve unrelated user changes.

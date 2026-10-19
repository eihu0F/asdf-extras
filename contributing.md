# Contributing

## Development Flow (Branch + Pull Request Required)

1. Sync local `main` and create a working branch.

```shell
git switch main
git pull --ff-only origin main
git switch -c issue-<number>-<short-topic>
```

### Branch Naming Rules

- If an issue already exists, branch name must include the issue number:
	- `issue-<number>-<short-topic>`
	- Example: `issue-123-install-parent-option`
- If no issue exists, branch name must explicitly indicate that state:
	- `noissue-<short-topic>`
	- Example: `noissue-update-contributing-guide`
- Branch names do not need a commit/PR type prefix.

2. Make changes and run local validation.

```shell
bash ./scripts/test-local.bash
```

3. Commit and push the branch.

```shell
git add -A
git commit
git push -u origin <branch-name>
```

4. Open a pull request and merge via PR review flow.

Rules:

- Do not push development changes directly to `main`.
- PR titles must follow Conventional Commits format (`<type>: <subject>`).
- Wait for required checks before merge.

Testing Locally:

```shell
# Optional: install local tooling versions declared in .tool-versions
asdf install

bash ./scripts/test-local.bash
```

What this script does:

1. Verifies local `asdf` version is `>= 0.16.0`.
2. Verifies `asdf plugin test` command exists on your asdf version.
3. Runs `asdf plugin test` for this plugin.
4. If plugin-test fails only because installable versions cannot be listed, runs fallback local smoke checks.

Manual plugin-test command:

```shell
asdf plugin test asdf-extras https://github.com/eihu0F/asdf-extras.git "asdf-extras --help"
```

Note:
- If this repository has no release tags yet, `asdf plugin test` may fail with `Unable to list available versions`.
- In that case, use `scripts/test-local.bash` as the default local test entrypoint.

Tests are automatically run in GitHub Actions on push and PR.

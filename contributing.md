# Contributing

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

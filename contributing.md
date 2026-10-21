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

Run install command regression tests without installing asdf:

```shell
/bin/bash ./scripts/test-install.bash
/bin/bash ./scripts/test-update.bash
/bin/bash ./scripts/test-update-asdf.bash
/bin/bash ./scripts/test-init-refresh.bash
/bin/bash ./scripts/test-help.bash
/bin/bash ./scripts/test-completion.bash
/bin/bash ./scripts/test-completion-elvish.bash
/bin/bash ./scripts/test-completion-nushell.bash
```

These tests check option forwarding and argument validation, including empty-array
handling under `set -u` with macOS system Bash 3.2. CI runs them with system Bash
on both Linux and macOS.

Update regression tests verify that installation and activation failures retain
the previous version, and that bulk updates continue with subsequent plugins.
They also cover scope selection, home-only cleanup, sequential plugin updates,
and shared install hooks. Install tests exercise Bash/Zsh/Fish routing when those
shells are available and native `asdf set` when asdf is installed.
Self-update tests require jq and use isolated mock downloads, Homebrew and custom
scripts; they never update the developer's asdf installation or access the network.
Shell refresh tests exercise each available Bash/Zsh/Fish shell using isolated
old/new runtimes, including removal of the old runtime and partial update failures.
When Elvish or Nushell is available, they also verify reload reminders on successful
and failed updates without suppressing update output or failures.
Help tests exercise all available init shells, including Nushell multiword
command routing. They verify native help preservation, extras topics, plugin
delegation, native failure statuses, repeated initialization and standalone/plugin
help consistency. Install/update/completion use `--help` and `-h`, including
flags after other arguments, without running the command's normal actions.
Native install-specific help is preserved, and `help install` / `help update`
remain plugin-help requests. Elvish failures are compared against the shell's native
external-command failure behavior rather than assuming a process exit code.
Completion tests verify native handler discovery and registration preservation,
repeated initialization, scope/target argument positions, and explicit failures.
They also verify that standalone completion registers `asdf-extras` without
installing command wrappers or changing native `asdf` completion.
Combined-mode tests verify `--asdf` with either option position, both registrations
without command wrappers, and automatic mode selection by initialized wrappers.
Elvish completion tests require Elvish >= 0.21.0, util-linux `script`, and
coreutils `timeout` (Linux). They use a real interactive editor under a pseudo-terminal to
verify standalone isolation, native function discovery/loading, rich candidate
preservation, scope normalization, repeated registration, initialized routing,
and visible native-loading/query failures. They also send real TAB keystrokes
and verify both command names' completion through the editor.
The dedicated CI job pins Elvish 0.21.0.
Nushell completion tests require `nu` >= 0.116.1 (otherwise they skip). They use
the real completion engine and a mock native module to verify signature
delegation, structured native output, standalone isolation, repeated setup,
option positions, initialized routing, and native-loading/query failures.
Quoted literal arguments and unfinished quoted prefixes are tested without
evaluating expressions; native delegation retains the original source tokens.
Failure tests also invoke `commandline complete` in default-config-free sessions
and assert visible stderr diagnostics for all three Bash query paths.
They exercise Bash 3.2-compatible behavior and each available Zsh/Fish shell;
no real plugins are installed or updated.

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

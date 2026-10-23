# Contributing

## Workflow

1. Create a branch from an up-to-date `main`.
2. Make your changes and run the [tests](#testing).
3. Open a pull request. Do not push development changes directly to `main`.
4. Wait for the required checks, then merge through PR review.

PR titles follow Conventional Commits: `<type>: <subject>`.

### Branch names

| Situation | Name | Example |
| --- | --- | --- |
| An issue exists | `issue-<number>-<short-topic>` | `issue-123-install-parent-option` |
| No issue exists | `noissue-<short-topic>` | `noissue-update-contributing-guide` |

Branch names do not need a commit or PR type prefix.

## Testing

Run the full local check before opening a PR:

```shell
# Optional: install the tool versions declared in .tool-versions
asdf install

bash ./scripts/test-local.bash
```

`test-local.bash` does the following:

1. Checks that your `asdf` is version 0.16.0 or later.
2. Checks that your `asdf` provides `asdf plugin test`.
3. Runs `asdf plugin test` for this plugin.
4. If the plugin test fails only because no installable versions can be listed, runs fallback smoke checks.

A repository without release tags can make `asdf plugin test` fail with
`Unable to list available versions`. The fallback checks cover that case, so use
`test-local.bash` as the default entry point.

To run the plugin test by itself:

```shell
asdf plugin test asdf-extras https://github.com/eihu0F/asdf-extras.git "asdf-extras --help"
```

After editing shell scripts, also run `./scripts/lint.bash` (`shellcheck` and `shfmt`).

### Regression tests

These scripts run without installing asdf. They use temporary directories and mock
downloads, so they never touch your asdf installation, installed plugins, or the
network. CI runs them with the system Bash on both Linux and macOS, so scripts must
also work with macOS Bash 3.2 (for example, empty arrays under `set -u`).

```shell
/bin/bash ./scripts/test-<name>.bash
```

| Script | What it covers | Extra requirements |
| --- | --- | --- |
| `test-install.bash` | `install` options, argument validation, and Bash/Zsh/Fish routing | None |
| `test-prune.bash` | Removal of unused versions by `prune` | None |
| `test-update.bash` | `update` scopes, failure handling, and runtime self-update | None |
| `test-update-asdf.bash` | `update --asdf` self-update | `jq` |
| `test-init-refresh.bash` | Shell initialization refresh after an update | None |
| `test-help.bash` | `--help` and `help` routing for every available init shell | None |
| `test-completion.bash` | Completion registration for Bash, Zsh, and Fish | None |
| `test-completion-elvish.bash` | Completion through a real interactive Elvish editor | Elvish 0.21.0 or later, util-linux `script`, coreutils `timeout` (Linux) |
| `test-completion-nushell.bash` | Completion through the real Nushell completion engine | `nu` 0.116.1 or later |

Shell-specific parts run only for the shells you have installed. The Nushell test
skips itself when `nu` is missing. CI installs pinned Elvish and Nushell versions
in dedicated jobs.

Some behavior is covered in more detail than the table shows:

- **Update:** a failed install or activation keeps the previous version, and a bulk
  update continues with the remaining plugins. Plugin, self-install, and cleanup
  failures preserve a nonzero exit status.
- **Help:** native `asdf` help is preserved. `help install` and `help update` stay
  plugin-help requests. `--help` and `-h` never run the command itself.
- **Completion:** standalone completion never installs command wrappers or changes
  native `asdf` completion. Native loading and query failures are reported on stderr.

## Agent skills

Instructions for coding agents are kept as skills, not as per-tool instruction files.

- `.agents/skills/` is the source of truth. Edit skills only there.
- `.claude/skills/` is a plain copy for Claude Code. Never edit it directly, and do not use symlinks.
- `AGENTS.md`, `.claude/CLAUDE.md`, and `.github/copilot-instructions.md` are one-line entry points that load the `project-rules` skill. Put real instructions in skills.

After finishing your edits, refresh the copy and check that nothing differs, then commit both directories together:

```shell
rm -rf .claude/skills && mkdir -p .claude && cp -R .agents/skills .claude/skills
diff -r .agents/skills .claude/skills && echo "skills in sync"
```

See `.agents/skills/add-skill/SKILL.md` for details.

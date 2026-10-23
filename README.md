<div align="center">

# asdf-extras [![Build](https://github.com/eihu0F/asdf-extras/actions/workflows/build.yml/badge.svg)](https://github.com/eihu0F/asdf-extras/actions/workflows/build.yml) [![Lint](https://github.com/eihu0F/asdf-extras/actions/workflows/lint.yml/badge.svg)](https://github.com/eihu0F/asdf-extras/actions/workflows/lint.yml)

[asdf-extras](https://github.com/eihu0F/asdf-extras) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

asdf-extras adds tool updates, install-and-activate commands, and version cleanup
to [asdf](https://asdf-vm.com). Initialize your shell once, then use
`asdf update` to update asdf, plugin definitions, and tools, or
`asdf install --home nodejs latest` to install and activate a home version.
Other `asdf` commands retain their native behavior.

# Contents

- [Dependencies](#dependencies)
- [Quick start](#quick-start)
- [Usage](#usage)
  - [Update plugins and tools](#update-plugins-and-tools)
  - [Install and activate a version](#install-and-activate-a-version)
  - [Prune unused versions](#prune-unused-versions)
  - [Discover extensions through help](#discover-extensions-through-help)
- [Reference](#reference)
  - [Command names and terminology](#command-names-and-terminology)
  - [Update options and defaults](#update-options-and-defaults)
  - [Update environment variables](#update-environment-variables)
  - [Scopes and version cleanup](#scopes-and-version-cleanup)
  - [Install-time environment hooks](#install-time-environment-hooks)
- [Shell support](#shell-support)
- [Advanced usage](#advanced-usage)
  - [Updating asdf itself](#updating-asdf-itself)
  - [Direct invocation without init](#direct-invocation-without-init)
- [Contributing](#contributing)
- [Related projects](#related-projects)
- [License](#license)

# Dependencies

- `asdf` `>= 0.16.0`
- `jq` for built-in standalone asdf executable updates (not required for custom
  update scripts, Homebrew updates, or plugin/tool-only updates).
- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).

# Quick start

## 1. Install asdf-extras

```shell
asdf plugin add asdf-extras https://github.com/eihu0F/asdf-extras.git
asdf cmd asdf-extras install asdf-extras latest
```

The repository URL is required because the plugin is not in the asdf plugin
index. `asdf cmd asdf-extras` runs the plugin checkout to bootstrap installation;
afterward, `asdf-extras` runs the installed version selected by asdf.

## 2. Initialize your shell

Add the appropriate lines to your shell startup configuration and run them in your
current shell, after any framework or native asdf completion setup:

```bash
# Bash
eval "$(asdf-extras init bash)"
# Optional: enable completion if you use it.
eval "$(asdf completion bash)"
```

```zsh
# Zsh
eval "$(asdf-extras init zsh)"
# Optional: enable completion if you use it.
eval "$(asdf completion zsh)"
```

`init` enables command extensions such as `asdf update`; it does not load
completion. `asdf completion <shell>` enables completion for both `asdf` and
`asdf-extras`, and must come **after** `init`: after initialization, the wrapper
routes it to combined completion, while before initialization it prints native
asdf completion only. The shell name is required. Type `asdf update --` and
press Tab to see completion candidates.
For other shells and copyable completion-only examples, see the
[shell guide](docs/shells.md).

## 3. Try an extended command

```shell
asdf update nodejs
```

This updates the plugin definition, installs its latest tool version, and
activates it in the home configuration. See [Usage](#usage) for other commands
and [Scopes and version cleanup](#scopes-and-version-cleanup) before updating
versions shared with projects.

# Usage

These examples assume shell initialization is enabled. Update and scoped install
are available through `asdf`; prune is a separate `asdf-extras` command, not an
extension of `asdf prune`.

## Update plugins and tools

| Example | Action |
| --- | --- |
| `asdf update` | Update asdf itself, plugin definitions, and tools (equivalent to `asdf update --all`) |
| `asdf update nodejs` | Update one plugin definition and activate its latest tool version |
| `asdf update nodejs 24.11.0` | Update one plugin definition and activate a specific tool version |
| `asdf update --use-latest nodejs 24` | Resolve and activate the latest version matching a prefix |
| `asdf update --local` | Update plugin definitions and tools listed in the current directory's configuration |
| `asdf update --parent nodejs` | Update one plugin definition and tool using the closest parent configuration |
| `asdf update --plugin --version` | Update plugin definitions and tools without updating asdf itself |

See [Update options and defaults](#update-options-and-defaults) for target
selection, failure handling, and environment settings.

## Install and activate a version

```shell
asdf install --home nodejs latest
```

Use a [scope option](#scopes-and-version-cleanup) to install through asdf-extras
and activate the version in the selected configuration. `latest` and
`latest:<prefix>` are resolved before comparison and installation.

Only installs with a scope option are routed through asdf-extras.
Plain `asdf install` keeps native asdf behavior, even after initialization.
asdf-extras installs can also load environment files and run
[install-time hooks](#install-time-environment-hooks).

## Prune unused versions

> [!WARNING]
> Prune uninstalls versions immediately, without a confirmation prompt or dry-run
> mode. It uses only the home configuration, so it can remove versions still
> referenced by projects. Ensure the home file lists every version you want to
> keep. A plugin absent from that file has **all** its installed versions removed.

```shell
asdf-extras prune
# Prune only one plugin
asdf-extras prune nodejs
```

With no plugin argument, prune checks all installed plugins. With a plugin
argument, it checks only that plugin. It retains every version listed for the
plugin in the home configuration, including fallback versions.
See [Scopes and version cleanup](#scopes-and-version-cleanup) for configuration
file naming.

If the home configuration is missing or unreadable, prune stops without
uninstalling anything. Uninstall failures are reported; pruning continues for
other versions and returns a nonzero status.

## Discover extensions through help

| Command | Help shown after initialization |
| --- | --- |
| `asdf help` | Native help followed by a short asdf-extras summary |
| `asdf update --help` | Update targets, defaults, scopes, and cleanup |
| `asdf install --help` | Native install help followed by scope and activation guidance |
| `asdf-extras prune --help` | Home-based cleanup behavior |
| `asdf completion --help` | Completion modes and shell setup |

Each subcommand also accepts `-h` without performing its normal action.
Native general/install help must succeed before asdf-extras guidance is appended.
Native asdf uses `help <plugin> [version]` for plugin documentation and
`<subcommand> --help` for command-specific help. All
`asdf help <plugin> [version]` requests are delegated unchanged, preserving failures.

Without initialization, native help is unchanged. Use
`asdf-extras <subcommand> --help`, `asdf-extras help <topic>`, or
`asdf cmd asdf-extras help <topic>` for asdf-extras documentation.
Through `asdf cmd`, use the explicit `help <topic>` form: asdf versions such as
0.20.2 do not successfully forward `<subcommand> --help` to the plugin.
Plain `asdf-extras help` includes all three command topics.

# Reference

## Command names and terminology

| Term or command | Meaning |
| --- | --- |
| asdf-extras plugin / plugin checkout | The repository registered with `asdf plugin add`; contains the code used by `asdf cmd asdf-extras` |
| Installed runtime | A released version of asdf-extras installed and selected through asdf |
| `asdf-extras` | Runs the selected installed runtime |
| `asdf cmd asdf-extras` | Runs the plugin checkout, including before a runtime is installed |
| Initialized `asdf` wrapper | Shell definitions generated by `asdf-extras init <shell>`; route extended commands to the installed runtime and delegate other commands to native asdf |

The two direct invocation forms provide the same subcommands but can run different
versions of the code. Use the installed `asdf-extras` command for normal direct
invocation and the plugin checkout for bootstrapping.

## Update options and defaults

### Target selection

| Invocation or target option | Targets |
| --- | --- |
| `asdf update` with no arguments | asdf itself, plugin definitions, and tool versions |
| `--all` | asdf itself, plugin definitions, and tool versions, in that order |
| No target flags, with a plugin or scope | Plugin definitions and tool versions |
| `--asdf` | asdf executable only |
| `--plugin` | Plugin definitions only |
| `--version` | Tool versions only |

- `--asdf`, `--plugin`, and `--version` can be combined.
- `--all` cannot be combined with other target flags or a plugin/version
  argument. Positional `all` is not a target selector.
- A target version argument requires tool version updates.
- The update target `--version` is distinct from the top-level
  `asdf-extras version` command.
- Scope options have no effect when tool version updates are not selected.
- An omitted plugin processes the applicable plugin set; see
  [Scopes and version cleanup](#scopes-and-version-cleanup).

### Version resolution

| Mode | Explicit version argument | Omitted version argument |
| --- | --- | --- |
| Default | Use the requested version; resolve `latest` or `latest:<prefix>` | Use `ASDF_EXTRAS_UPDATE_DEFAULT_VERSION` (default: `latest`), with a plugin-specific override if set |
| `--use-latest` or enabled use-latest environment setting | Treat the argument as an `asdf latest` prefix | Use the configured latest prefix; if empty, call `asdf latest <plugin>` without a prefix |

See [Update environment variables](#update-environment-variables) for overrides.

### Processing and failures

When both plugin and tool targets are selected, asdf-extras updates each plugin
definition, then delegates installation and activation to its install command.
It does not run `asdf plugin update --all`.

Install compares the target with the version in the selected configuration.
If they match and the version is installed, it skips installation, configuration
changes, and hooks. Otherwise it installs the target and writes the selected
configuration, even when another configuration or environment variable shadows it.

Failures are reported and remaining updates continue, including when updating
asdf itself fails. Bulk updates warn and skip a plugin whose latest version
cannot be resolved, allowing other plugins to update. The command returns
nonzero if any requested update fails, including unresolved latest versions.

Home-scoped bulk tool updates process the asdf-extras plugin last when it is in
the selected set, preserving other plugins' order. This keeps the running runtime
available until its replacement is installed. Parent/local and plugin-only
updates keep the original order because they do not remove old runtimes.
Use `ASDF_EXTRAS_PLUGIN_NAME` if the plugin is registered under another name.

## Update environment variables

In variable suffixes below, `<PLUGIN>` is the uppercase plugin name with
non-alphanumeric characters replaced by `_` (for example, `NODEJS`).
Plugin-specific settings override their global counterparts.

| Variable | Default | Purpose |
| --- | --- | --- |
| `ASDF_EXTRAS_UPDATE_DEFAULT_VERSION` | `latest` | Version used when no argument is supplied and use-latest mode is disabled |
| `ASDF_EXTRAS_UPDATE_DEFAULT_VERSION_<PLUGIN>` | Global setting | Plugin-specific default version |
| `ASDF_EXTRAS_UPDATE_USE_LATEST` | Disabled | Enable latest-prefix resolution with a nonzero value, such as `1` |
| `ASDF_EXTRAS_UPDATE_USE_LATEST_<PLUGIN>` | Global setting | Enable latest-prefix resolution with a nonzero value, or disable it with `0`, for one plugin |
| `ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX` | Empty | Default prefix in use-latest mode; empty resolves latest without a prefix |
| `ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX_<PLUGIN>` | Global setting | Plugin-specific default prefix |
| `ASDF_EXTRAS_PLUGIN_NAME` | `asdf-extras` | Registered plugin name used to process the runtime's home-scoped bulk update last |

For example, `ASDF_EXTRAS_UPDATE_DEFAULT_VERSION_NODEJS=24.11.0` selects a
specific default version for Node.js. `--use-latest` explicitly selects
latest-prefix resolution for an invocation.

## Scopes and version cleanup

Install and update accept these mutually exclusive scope options in any argument
position. Configuration files are named `.tool-versions`, or use
`ASDF_DEFAULT_TOOL_VERSIONS_FILENAME` when set.

| Scope | Configuration and activation | Previous versions after update |
| --- | --- | --- |
| `-u` / `--home` (default for update and direct `asdf-extras install`) | Home directory; `asdf set --home` | Removed only after successful installation and verified activation |
| `-p` / `--parent` | Closest existing configuration in a parent directory; `asdf set --parent` | Retained |
| `--local` | Current directory; `asdf set` | Retained |

Home and local files are created when needed. Parent scope fails before
installation if no parent configuration exists. `--current` is not a scope option.
Initialized `asdf install` requires an explicit scope to use asdf-extras;
unscoped installation remains native.

| Bulk tool update scope | Plugins selected |
| --- | --- |
| Explicit scope, no plugin argument | Only plugins listed in that configuration; a missing file is an error |
| No scope option, no plugin argument | All installed plugins; writes the home configuration |

Home-scoped update removes previous configured versions only after installation
succeeds, the target is confirmed installed, and activation succeeds and is
verified. Installation failure prevents activation. Failed or unverifiable
activation retains previous installations. Install itself never removes previous
versions; cleanup belongs to update.

> [!WARNING]
> Home-scoped update cleanup can affect projects that still reference an old
> version. Use parent or local scope when those versions must be retained.

## Install-time environment hooks

Hooks apply to installs routed through asdf-extras: scoped `asdf install` after
initialization, direct `asdf-extras install`, and the installation step of
`update`. They do not apply to plain `asdf install`. Already-configured,
installed versions are skipped without running hooks.

| Setting | Purpose |
| --- | --- |
| `${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras/install/env/<plugin>.env` | Default environment file |
| `ASDF_EXTRAS_INSTALL_ENV_DIR` | Override the environment directory |
| `ASDF_EXTRAS_INSTALL_ENV_FILE_<PLUGIN>` | Override the file for one plugin |
| `ASDF_EXTRAS_INSTALL_ENV_FUNCTION_<PLUGIN>` | Hook function for one plugin |
| `ASDF_EXTRAS_INSTALL_ENV_FUNCTION` | Global fallback hook function |

`<PLUGIN>` uses the same normalization as
[update environment variables](#update-environment-variables). An existing
environment file is sourced before installation. If a hook function variable
is set, the function runs as `<function> <plugin> <version>` before installation.
The plugin-specific function takes precedence over the global fallback.

```shell
mkdir -p "${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras/install/env"

cat >"${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras/install/env/nodejs.env" <<'EOF'
export CC=clang
export CXX=clang++

nodejs_build_env() {
	export PYTHON=/usr/bin/python3
}
EOF

export ASDF_EXTRAS_INSTALL_ENV_FUNCTION_NODEJS=nodejs_build_env
asdf-extras install nodejs 24.11.0
```

# Shell support

Initialization supports Bash, Zsh, Fish, Elvish, and Nushell. It enables command
wrappers only. Enable completion for both `asdf` and `asdf-extras` afterward with
`asdf completion <shell>`, which the initialized wrapper routes to combined
completion. Load framework/native completion before asdf-extras setup.

| Shell | Startup initialization, then completion | Notes |
| --- | --- | --- |
| [Bash](docs/shells.md#bash) | `eval "$(asdf-extras init bash)"`<br>`eval "$(asdf completion bash)"` | Load after native completion |
| [Zsh](docs/shells.md#zsh) | `eval "$(asdf-extras init zsh)"`<br>`eval "$(asdf completion zsh)"` | Load after `compinit` or framework setup |
| [Fish](docs/shells.md#fish) | `asdf-extras init fish \| source`<br>`asdf completion fish \| source` | Preserves native completion rules |
| [Elvish](docs/shells.md#elvish) | See linked setup for `rc.elv` | Requires >= 0.21.0 and an interactive editor for completion |
| [Nushell](docs/shells.md#nushell) | Save `init nushell` output, then source it from `config.nu` | Requires >= 0.116.1; regenerate the file after runtime changes |

Initialized Bash/Zsh/Fish wrappers refresh automatically when an update changes
the selected runtime. Elvish/Nushell require a new session if it changes.
Direct `asdf-extras update` does not refresh the current shell.

See the [shell guide](docs/shells.md) for setup details,
[completion-only modes](docs/shells.md#which-completion-command-should-i-use), native completion
coexistence, and [refresh behavior](docs/shells.md#shell-refresh-after-updates).

# Advanced usage

## Updating asdf itself

`asdf update --asdf` (or direct `asdf-extras update --asdf`) updates the asdf
executable, not the asdf-extras plugin or installed runtime. Only the latest
stable release is supported. See [target selection](#target-selection) for
including or excluding this step from a broader update.

The updater selects the first applicable method:

1. If `${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras/update-asdf.bash` exists, run it
   with Bash and pass the absolute path of the active asdf executable as `$1`.
   It is a user-maintained script, not sourced shell code. It must return nonzero
   on failure and is responsible for safe installation and validation.
2. If the resolved executable is inside the asdf formula's Homebrew cellar,
   run `brew upgrade asdf`. Merely having `brew` on PATH does not select it.
3. Otherwise, update a user-owned, writable, non-symlink standalone executable
   under the home directory from official Linux/macOS release assets.

Standalone updates require `jq` and either `sha256sum` or `shasum`. They check the
GitHub release's SHA-256 digest, extract and execute the candidate to verify its
version, then replace the old executable with a same-filesystem rename. Failures
before replacement retain the original binary; installed versions newer than or
equal to the latest release are not downgraded. No privileged commands are run.
Version checks accept both plain versions (such as `v0.20.2`) and the
`asdf version v0.20.2 (revision ...)` output format.
GitHub API/network failures are reported, not treated as successful updates.

Other package managers, symlink layouts, system-wide installations, and unsupported
platforms require a custom script. For example, adapt the following to your
installation method:

```shell
mkdir -p "${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras"
cat >"${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras/update-asdf.bash" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Example for an asdf installation managed by Homebrew.
brew upgrade asdf
"$1" --version
EOF
```

The asdf executable updater does not edit shell startup files or refresh asdf-extras
initialization itself; [shell refresh](docs/shells.md#shell-refresh-after-updates) is handled
by the initialized update wrapper. Executable discovery ignores the initialized
`asdf` shell function and uses the first executable on PATH.

## Direct invocation without init

Shell initialization is recommended for normal use. Without it, use
`asdf-extras` directly:

```shell
asdf-extras update
asdf-extras update nodejs
asdf-extras install nodejs 24.11.0
```

The same [update rules](#update-options-and-defaults) apply.
Direct `asdf-extras install` defaults to home activation and also accepts the
[scope options](#scopes-and-version-cleanup).

Without initialization, ordinary `asdf` commands are not extended: `asdf update`
is not provided by asdf-extras, and `asdf install` retains native behavior.
See [Command names and terminology](#command-names-and-terminology) for the
difference between installed-runtime and plugin-checkout invocation.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).
Please follow the [Code of Conduct](.github/CODE_OF_CONDUCT.md). To report a
vulnerability, see the [Security Policy](.github/SECURITY.md).

[Thanks goes to these contributors](https://github.com/eihu0F/asdf-extras/graphs/contributors)!

# Related projects

- [asdf](https://github.com/asdf-vm/asdf): the version manager that asdf-extras extends.

# License

See [LICENSE](LICENSE) © [BuffieLead](https://github.com/eihu0F/)

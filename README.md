<div align="center">

# asdf-extras [![Build](https://github.com/eihu0F/asdf-extras/actions/workflows/build.yml/badge.svg)](https://github.com/eihu0F/asdf-extras/actions/workflows/build.yml) [![Lint](https://github.com/eihu0F/asdf-extras/actions/workflows/lint.yml/badge.svg)](https://github.com/eihu0F/asdf-extras/actions/workflows/lint.yml)

[asdf-extras](https://github.com/eihu0F/asdf-extras) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

asdf-extras extends [asdf](https://asdf-vm.com) with commands for updating tools
and installing and activating versions in one step. Initialize your shell once,
then use the extensions through normal `asdf` commands:

- `asdf update`: update asdf itself and plugin definitions, install the latest tool versions,
  and activate them in your home configuration. Previous versions are removed
  only after successful installation and verified activation.
- `asdf install -u` / `asdf install -p` / `asdf install --local`: install a
  version and activate it in your home, a parent, or the current directory's configuration.
- Customize extras installs with plugin-specific environment files and hooks.

Other `asdf` commands retain their native behavior.

# Contents

- [Dependencies](#dependencies)
- [Quick start](#quick-start)
- [Commands](#commands)
  - [Update plugins and tools](#update-plugins-and-tools)
  - [Install and activate a version](#install-and-activate-a-version)
- [Advanced usage](#advanced-usage)
  - [Updating asdf itself](#updating-asdf-itself)
  - [Direct invocation without init](#direct-invocation-without-init)
  - [Install-time environment hooks](#install-time-environment-hooks)
  - [Completion output](#completion-output)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `asdf` `>= 0.16.0`
- `jq` for built-in standalone asdf executable updates (not required for custom
  update scripts, Homebrew updates, or plugin/tool-only updates).
- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).

# Quick start

## 1. Add the plugin and install asdf-extras

Add the plugin using its repository URL, then install and activate the latest
release:

```shell
asdf plugin add asdf-extras https://github.com/eihu0F/asdf-extras.git
asdf cmd asdf-extras install asdf-extras latest
```

The plugin is not listed in the asdf plugin index, so the URL is required.
The second command uses the plugin checkout to bootstrap installation before
the `asdf-extras` command is available.

## 2. Initialize your shell

Initialize your shell to use extras features through normal `asdf` commands.
For Bash, add this line to your shell startup configuration and run it in your
current shell:

```shell
eval "$(asdf-extras init bash)"
```

For Zsh, use `eval "$(asdf-extras init zsh)"` instead.

For Nushell 0.116.1 or newer, generate a file and source it from `config.nu`:

```nu
^asdf-extras init nushell | save --force ~/.asdf-extras-init.nu
# Add this line to config.nu, then start a new session:
source ~/.asdf-extras-init.nu
```

Supported shells for `init`: `bash`, `elvish`, `fish`, `nushell`, `zsh`.
The examples above use Bash/Zsh syntax; other shells must load the generated
initialization code using their own syntax.

In Bash, Zsh, and Fish, the initialized `asdf update` wrapper reloads initialization
from the newly selected asdf-extras executable when its path changes. This keeps
the current shell usable after an update removes the old installed runtime.
The wrapper resolves the new executable with `asdf which asdf-extras`, rather
than using the old shim or dispatcher.

If a bulk update reports a failure but successfully changes the selected extras
installation, initialization is still refreshed and the update's failure status
is preserved. If extras remains unchanged, no initialization is evaluated.
Refresh failures report an error and return nonzero. Startup configuration files
are never rewritten.

Automatic refresh currently applies only to initialized Bash/Zsh/Fish wrappers,
not direct `asdf-extras update` calls. Elvish and Nushell wrappers display a
reminder after every update, including failures, to start a new shell session if
extras changed. This reloads startup initialization without referencing a removed
runtime. They do not automatically reload definitions in the current shell.
The Bash/Zsh/Fish refresh reloads extras initialization and its completion overlay.
Existing native completion definitions are retained.

## 3. Use the extended commands

After initialization, use normal `asdf` commands:

```shell
# Update asdf itself, plugins and tools
asdf update

# Update one plugin and activate its latest version
asdf update nodejs

# Install and activate in the home configuration
asdf install -u nodejs 24.11.0

# Install and activate in a parent directory's configuration
asdf install -p nodejs 24.11.0
```

`asdf update` is equivalent to `asdf update --all`: it updates asdf itself as well
as plugins and tools. If a plugin's latest version
cannot be resolved, it is reported and skipped so other plugins can still update.
Successful updates remove the previous version only after installation and
verified activation; failed installation or activation retains the previous installation.

See [Commands](#commands) for update behavior and scope details. Direct calls
without shell initialization are covered under [Advanced usage](#advanced-usage).

# Commands

The examples in this section assume shell initialization is enabled.

## Update plugins and tools

```shell
# Update asdf itself, plugins and tools to the latest versions
asdf update
# Equivalent explicit form
asdf update --all

# Update one plugin and use its latest version
asdf update nodejs

# Update one plugin and use a specific version
asdf update nodejs 24.11.0

# Update only the tools listed in the selected project configuration
asdf update --local
asdf update --parent nodejs

# Select update targets (these flags can be combined)
asdf update --asdf
asdf update --plugin
asdf update --version nodejs
asdf update --plugin --version
```

`--all` updates asdf itself, plugin definitions and tool versions, in that order.
It cannot be combined with other target flags or a plugin/version argument.
Use `--all` instead of the former positional `all`.
`--asdf`, `--plugin`, and `--version` select those targets individually and can be
combined. The standalone `--version` here selects tool updates; it is not the
top-level extras version command.

With no target flags, specifying a plugin or scope updates plugin definitions and
tool versions; with no arguments, all three targets are selected. An omitted
plugin processes the applicable plugin set; an omitted version means latest.
A target version argument requires tool version updates. Scope options have no
effect when tool version updates are not selected.

Failures are reported and remaining updates continue, including when updating
asdf itself fails. The command returns nonzero if any requested update fails.
This also applies to unresolved latest versions during bulk updates.

When both plugin and tool targets are selected, extras updates each plugin
definition, then delegates installation
and activation to extras install. It does not run `asdf plugin update --all`.
Install compares the version in the selected configuration with the target;
if they match and the version is installed, no installation or setting change
is needed. Otherwise it installs the target and writes the selected configuration,
even when another configuration or environment variable shadows it.

Both install and update accept these mutually exclusive scope options in any
argument position:

| Scope | Configuration | Previous versions after update |
| --- | --- | --- |
| `-u` / `--home` (default) | Home directory | Removed after success |
| `-p` / `--parent` | Closest existing configuration in a parent directory | Retained |
| `--local` | Current directory | Retained |

Home and local configuration files are created when needed. Parent scope fails
before installation if no parent configuration file exists. Files are named
`.tool-versions`, or use `ASDF_DEFAULT_TOOL_VERSIONS_FILENAME` when set.
`--current` is not a scope option.

With an explicit scope and tool version updates selected, an omitted plugin only updates plugins
listed in that configuration file; a missing file is an error for bulk updates.
Without a scope option, bulk updates retain the existing behavior of processing
all installed plugins and writing the home configuration.

In home scope, the previous configured versions are uninstalled only after installation succeeds, the target
is confirmed installed, and activation succeeds and is verified. If installation
fails, activation is not attempted. If activation fails or cannot be verified,
the previous installation is retained. Parent and local updates never remove
previous versions. Home cleanup can affect projects that still reference an old
version; use a project scope when those versions must be retained.

## Install and activate a version

```shell
asdf install -u nodejs 24.11.0
asdf install -p nodejs 24.11.0
asdf install --local nodejs latest
```

- `-u` / `--home`: install, then activate with `asdf set --home`.
- `-p` / `--parent`: install, then activate with `asdf set --parent`.
- `--local`: install, then write the current directory's configuration with `asdf set`.
- Scope options cannot be combined. See the scope rules above.

`latest` and `latest:<prefix>` are resolved before comparison and installation.
Install never removes previous versions; home-scoped update performs cleanup.

Only installs with one of these scope options are routed through extras.
Plain `asdf install` keeps native asdf behavior, even after initialization.

Extras installs can load plugin-specific environment files and run hook functions
before installation. See [Install-time environment hooks](#install-time-environment-hooks).

# Advanced usage

## Updating asdf itself

`asdf update --asdf` (or direct `asdf-extras update --asdf`) updates the asdf
executable, not the asdf-extras plugin or runtime. Only the latest stable release
is supported. Without target flags, `asdf update` now includes this step; use
`--plugin --version` to retain plugin/tool-only updates.

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

The asdf executable updater does not edit shell startup files or refresh extras
initialization itself; the initialized Bash/Zsh/Fish update wrapper refreshes it
when the selected extras installation changes. Executable discovery ignores the initialized `asdf` shell
function and uses the first executable on PATH.

## Direct invocation without init

Shell initialization is recommended for normal use. Without it, use
`asdf-extras` directly:

```shell
asdf-extras update
asdf-extras update nodejs
asdf-extras install nodejs 24.11.0
```

The same [command behavior](#commands) applies. Direct `asdf-extras install`
activates in the home configuration by default; `--home`, `--parent`, and `--local` can also
be specified explicitly.

Without initialization, ordinary `asdf` commands are not extended: `asdf update`
is not provided by extras, and `asdf install` retains native behavior.

`asdf-extras` and `asdf cmd asdf-extras` provide the same subcommands, but use
different code:

- `asdf-extras` runs the installed version selected by asdf.
- `asdf cmd asdf-extras` runs the code in the plugin checkout, including for
  bootstrapping before extras itself is installed.

## Install-time environment hooks

Hooks apply to installs routed through extras (`asdf install -u/-p/--local` after
init, direct `asdf-extras install`, and the installation step of `update`).
They do not apply to plain `asdf install`. Already-configured, installed versions
are skipped without running hooks.

- Default env file location: `${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras/install/env/<plugin>.env`
- Optional env dir override: `ASDF_EXTRAS_INSTALL_ENV_DIR`
- Plugin-specific env file override: `ASDF_EXTRAS_INSTALL_ENV_FILE_<PLUGIN_NAME_UPPER>`
- Plugin-specific hook function: `ASDF_EXTRAS_INSTALL_ENV_FUNCTION_<PLUGIN_NAME_UPPER>`
- Global hook function fallback: `ASDF_EXTRAS_INSTALL_ENV_FUNCTION`

Notes:

- `<PLUGIN_NAME_UPPER>` is generated from plugin name by uppercasing and replacing non-alphanumeric characters with `_`.
- If env file exists, it is sourced before install.
- If hook function variable is set, that function is executed as `<function> <plugin> <version>` before install.
- Function resolution order is: plugin-specific (`..._FUNCTION_<PLUGIN_NAME_UPPER>`) first, then global (`..._FUNCTION`).

Example:

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

## Completion output

```shell
asdf-extras completion bash
```

For Bash, Zsh, Fish, and Nushell, normal `asdf-extras init <shell>` already enables
completion for both `asdf` and `asdf-extras`: no separate completion file or
additional startup command is needed.
After initialization, `asdf completion <shell>` routes to this command as well.
For Bash/Zsh/Fish/Nushell requests, the initialized wrapper automatically adds `--asdf`
to include the `asdf` overlay. Elvish requests are forwarded without
that option to retain their legacy output.

Without init, load completion for `asdf-extras` alone:

```bash
# Bash
eval "$(asdf-extras completion bash)"
```

```zsh
# Zsh (after framework/completion setup, if any)
eval "$(asdf-extras completion zsh)"
```

```fish
# Fish
asdf-extras completion fish | source
```

These commands register completion for `asdf-extras` without installing command
wrappers, loading native asdf completion, or changing its existing registration.
They complete extras subcommands, shell names, scopes, update targets, plugins,
and versions. Repeated loading does not duplicate registrations.

Use `asdf-extras completion --asdf <shell>` to register both `asdf-extras`
completion and the `asdf` overlay without installing command wrappers.
The default, with no `--asdf`, registers only `asdf-extras` completion.
Normal init uses `--asdf` mode automatically. This mode is supported for Bash,
Zsh, Fish, and Nushell; Elvish retains its legacy completion output pending
the follow-up integration below.

### Nushell setup and native coexistence

Completion requires **Nushell 0.116.1 or newer**. Save generated code before
sourcing it, because Nushell resolves source paths and command definitions at
parse time:

```nu
# Standalone completion only; does not install asdf wrappers.
^asdf-extras completion nushell | save --force ~/.asdf-extras-completion.nu
# Add this line to config.nu:
source ~/.asdf-extras-completion.nu
```

For the initialized workflow, use the Quick start's saved `init nushell` output
instead. Initialization already includes both completion modes.
Regenerate the saved file when changing the extras runtime, then start a new
Nushell session.

Combined mode embeds the output of `asdf completion nushell` unchanged and imports
its definitions before the extras overlay. Load any existing native asdf module
before extras initialization; do not import it again afterward, as that would
replace the extras signatures. The generated module is the native baseline.
Native commands such as `asdf plugin list` retain their structured return values.
Private aliases retain native root/install signatures for completion delegation;
extras does not copy the upstream completers. Only root, install, update and
completion signatures are extended, and initialized wrappers route the extended
commands to extras. Standalone completion does not load the native module.

When init is used, the additional `asdf` overlay works as follows:

The overlay adds `update`, install/update scope flags, update-target flags, and
plugin/version candidates even when scope flags appear between arguments.
It preserves upstream definitions and delegates ordinary commands to the existing
native completion handler. Repeated initialization does not stack wrappers.
Scoped install delegation retains arguments after the cursor as well as before
it. Update completion still offers unselected scope flags after `--all`, while
excluding incompatible update targets and positional arguments.

- **Bash:** discovers the registered function using `complete -p asdf`, retaining
  its registration options. If no completion is registered, it loads native
  `asdf completion bash`. External-command (`-C`) or other non-function
  registrations are left unchanged with an explicit error.
- **Zsh:** retains the handler registered by `compinit`, Oh My Zsh, or another
  framework. If none is registered, it loads native completion. Place extras init
  **after** framework/completion setup; if a framework replaces the registration
  later, run extras init again.
- **Fish:** adds conditional rules without erasing existing native registrations.
  Native completion is loaded only when no rules are registered.

Native completion loading and candidate-query failures are reported rather than
silently replaced with empty results. Elvish initialization still provides
command wrappers only; its completion integration is tracked in
[Elvish #27](https://github.com/eihu0F/asdf-extras/issues/27).

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/eihu0F/asdf-extras/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [BuffieLead](https://github.com/eihu0F/)

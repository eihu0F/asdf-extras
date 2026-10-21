<div align="center">

# asdf-extras [![Build](https://github.com/eihu0F/asdf-extras/actions/workflows/build.yml/badge.svg)](https://github.com/eihu0F/asdf-extras/actions/workflows/build.yml) [![Lint](https://github.com/eihu0F/asdf-extras/actions/workflows/lint.yml/badge.svg)](https://github.com/eihu0F/asdf-extras/actions/workflows/lint.yml)

[asdf-extras](https://github.com/eihu0F/asdf-extras) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

asdf-extras extends [asdf](https://asdf-vm.com) with commands for updating tools
and installing and activating versions in one step. Initialize your shell once,
then use the extensions through normal `asdf` commands:

- `asdf update`: update plugin definitions, install the latest tool versions,
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
  - [Direct invocation without init](#direct-invocation-without-init)
  - [Install-time environment hooks](#install-time-environment-hooks)
  - [Completion output](#completion-output)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `asdf` `>= 0.16.0`
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

Supported shells for `init`: `bash`, `elvish`, `fish`, `nushell`, `zsh`.
The examples above use Bash/Zsh syntax; other shells must load the generated
initialization code using their own syntax.

## 3. Use the extended commands

After initialization, use normal `asdf` commands:

```shell
# Update all plugins and upgrade tools
asdf update

# Update one plugin and activate its latest version
asdf update nodejs

# Install and activate in the home configuration
asdf install -u nodejs 24.11.0

# Install and activate in a parent directory's configuration
asdf install -p nodejs 24.11.0
```

`asdf update` is equivalent to `asdf update all`. If a plugin's latest version
cannot be resolved, it is reported and skipped so other plugins can still update.
Successful updates remove the previous version only after installation and
verified activation; failed installation or activation retains the previous installation.

See [Commands](#commands) for update behavior and scope details. Direct calls
without shell initialization are covered under [Advanced usage](#advanced-usage).

# Commands

The examples in this section assume shell initialization is enabled.

## Update plugins and tools

```shell
# Update all plugins and upgrade their tools to the latest versions
asdf update
# Equivalent explicit form
asdf update all

# Update one plugin and use its latest version
asdf update nodejs

# Update one plugin and use a specific version
asdf update nodejs 24.11.0

# Update only the tools listed in the selected project configuration
asdf update --local
asdf update --parent nodejs
```

An omitted plugin means `all`; an omitted version means the plugin's latest
available version. Bulk updates report failures (including an unresolved latest
version) and continue with the next plugin.

For each plugin, extras updates its plugin definition, then delegates installation
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

With an explicit scope, `update all` (or an omitted plugin) only updates plugins
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

This emits native `asdf completion` output followed by extras initialization code.
After initialization, `asdf completion <shell>` routes to this command as well.
Initialization alone does not load completion definitions, and the current
overlay does not add extras-specific completion candidates.
The shared scope flags described above therefore work at execution time but are
not yet offered as additional completion candidates.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/eihu0F/asdf-extras/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [BuffieLead](https://github.com/eihu0F/)

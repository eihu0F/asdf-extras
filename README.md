<div align="center">

# asdf-extras [![Build](https://github.com/eihu0F/asdf-extras/actions/workflows/build.yml/badge.svg)](https://github.com/eihu0F/asdf-extras/actions/workflows/build.yml) [![Lint](https://github.com/eihu0F/asdf-extras/actions/workflows/lint.yml/badge.svg)](https://github.com/eihu0F/asdf-extras/actions/workflows/lint.yml)

[asdf-extras](https://github.com/eihu0F/asdf-extras) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `asdf` `>= 0.16.0`
- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).

# Install

Plugin:

```shell
asdf plugin add asdf-extras
# or
asdf plugin add asdf-extras https://github.com/eihu0F/asdf-extras.git
```

Install and activate `asdf-extras` itself:

```shell
# Show all installable versions
asdf list-all asdf-extras

# Bootstrap install via plugin command
asdf cmd asdf-extras install asdf-extras latest

# Now the installed asdf-extras command is available
asdf-extras --help
```

Installation behavior:
- `download` checks out the requested version from this plugin repository.
- After installation, the installed version is used when you run `asdf-extras`.

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Usage

Recommended setup is to initialize your shell first:

```shell
eval "$(asdf-extras init bash)"
```

Supported shells for `init`: `bash`, `elvish`, `fish`, `nushell`, `zsh`.

After initialization, `asdf-extras` extends normal `asdf` usage by overriding selected commands.

## With `init` (primary usage)

Use normal `asdf` commands:

```shell
asdf update
asdf update nodejs
asdf install -u nodejs 24.11.0
asdf install -p nodejs 24.11.0
```

These are routed to extras features:

```shell
asdf update ...
# routed to
asdf-extras update ...

asdf install [options] (-u|--home|-p|--parent) [plugin] [version]
# routed to
asdf-extras install [options] [plugin] [version]
```

What this provides:

1. `install -u`/`install --home` installs and then activates the version with `asdf set --home`.
2. `install -p`/`install --parent` installs and then activates the version with `asdf set --parent`.
3. `-u`/`--home` and `-p`/`--parent` cannot be used together.
4. `update` with no plugin argument is treated as `update all`.
5. `update all` updates plugin definitions and upgrades installed versions when newer versions are available.
6. If `latest` cannot be resolved for a plugin during `update all`, that plugin is skipped and processing continues.
7. `update <plugin> [version]` compares current vs target, installs and activates target, then removes the previous current version when changed.
8. Completion keeps base `asdf` behavior and adds extras-aware entries.

## Without `init` (translation rules)

If you do not run `init`, command overriding is disabled.

- `asdf update ...` is not provided by asdf-extras.
- `asdf install ...` is not rewritten by asdf-extras.
- Use explicit `asdf-extras` commands directly.

Rule 1:

```shell
# do this directly (not asdf update)
asdf-extras update ...
```

Rule 2:

```shell
# do this directly (not asdf install)
asdf-extras install [options] [plugin] [version]
```

Rule 3:

```shell
asdf completion <shell>
# use
asdf-extras completion <shell>
```

`asdf-extras` and `asdf cmd asdf-extras` provide the same subcommands.

Version source difference:

- `asdf-extras`: runs the installed version selected by asdf.
- `asdf cmd asdf-extras`: runs the version that exists in the plugin checkout.

Supported subcommands:

1. Install and activate a plugin version.

```shell
asdf-extras install [plugin] [version]
```

Behavior:
- Installs the specified plugin version.
- Runs `set --home` for that plugin/version after installation by default.

2. Update all plugins and refresh installed commands that can be upgraded.

```shell
asdf-extras update
# same as
asdf-extras update all
```

Behavior:
- Updates all plugins.
- Updates already-installed commands that have newer available versions.
- If `latest` cannot be resolved for a plugin, it is skipped and processing continues.

3. Update one plugin and refresh installed commands to latest, then activate.

```shell
asdf-extras update [plugin]
```

Behavior:
- Updates the specified plugin.
- Treats omitted version as `latest`.
- Compares target version with current (`set -u`) version.
- If different, installs target version, runs `set -u`, and uninstalls the previous current version.
- If identical, does nothing.

4. Set one plugin to a specific version and activate it.

```shell
asdf-extras update [plugin] [version]
```

Behavior:
- Updates the specified plugin.
- Compares target version with current (`set -u`) version.
- If different, installs target version, runs `set -u`, and uninstalls the previous current version.
- If identical, does nothing.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/eihu0F/asdf-extras/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [BuffieLead](https://github.com/eihu0F/)

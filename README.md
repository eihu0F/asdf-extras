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

Default usage is the installed command:

```shell
asdf-extras [subcommand]
```

`asdf-extras` and `asdf cmd asdf-extras` provide the same subcommands.

Version source difference:
- `asdf-extras`: runs the installed version selected by asdf.
- `asdf cmd asdf-extras`: runs the version that exists in the plugin checkout.

Shell initialization:

```shell
eval "$(asdf-extras init bash)"
```

Supported shells for `init`: `bash`, `elvish`, `fish`, `nushell`, `zsh`.

`init` defines an `asdf` shell function wrapper to extend `asdf` command behavior and adds extras-aware completion.
After initialization, the following behavior changes are applied.

1. `update` is delegated to extras.

```shell
asdf update ...
# delegated to
asdf-extras update ...
```

2. `install` is delegated to extras only when `-u` is specified.

```shell
asdf install -u [plugin] [version]
# delegated to
asdf-extras install [plugin] [version]
```

3. Completion keeps existing behavior and adds entries for `extras init` usage.

Supported subcommands:

1. Install and activate a plugin version.

```shell
asdf-extras install [plugin] [version]
```

Behavior:
- Installs the specified plugin version.
- Runs `set -u` for that plugin/version after installation.

2. Update all plugins and refresh installed commands that can be upgraded.

```shell
asdf-extras update
# same as
asdf-extras update all
```

Behavior:
- Updates all plugins.
- Updates already-installed commands that have newer available versions.

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

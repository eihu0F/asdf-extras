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

- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).

# Install

Plugin:

```shell
asdf plugin add asdf-extras
# or
asdf plugin add asdf-extras https://github.com/eihu0F/asdf-extras.git
```

asdf-extras:

```shell
# Show all installable versions
asdf list-all asdf-extras

# Install specific version
asdf install asdf-extras latest

# Set a version globally (on your ~/.tool-versions file)
asdf global asdf-extras latest

# Now asdf-extras commands are available
asdf-extras --help
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Usage

`asdf-extras` extends existing `asdf` commands.

Base command:

```shell
asdf cmd extras [subcommand]
```

Shell initialization:

```shell
eval "$(asdf cmd extras init bash)"
```

`init` overrides the `asdf` shell function behavior and adds extras-aware completion.
After initialization, the following behavior changes are applied.

1. `update` is delegated to extras.

```shell
asdf update ...
# delegated to
asdf cmd extras update ...
```

2. `install` is delegated to extras only when `-u` is specified.

```shell
asdf install -u [plugin] [version]
# delegated to
asdf cmd extras install [plugin] [version]
```

3. Completion keeps existing behavior and adds entries for `extras init` usage.

Supported subcommands:

1. Install and activate a plugin version.

```shell
asdf cmd extras install [plugin] [version]
```

Behavior:
- Installs the specified plugin version.
- Runs `set -u` for that plugin/version after installation.

2. Update all plugins and refresh installed commands that can be upgraded.

```shell
asdf cmd extras update all
```

Behavior:
- Updates all plugins.
- Updates already-installed commands that have newer available versions.

3. Update one plugin and refresh installed commands to latest, then activate.

```shell
asdf cmd extras update [plugin]
```

Behavior:
- Updates the specified plugin.
- Updates installed commands for that plugin to the latest available version.
- Runs `set -u` after update.

4. Set one plugin to a specific version and activate it.

```shell
asdf cmd extras update [plugin] [version]
```

Behavior:
- Sets the specified plugin to the given version.
- Runs `set -u` for that plugin/version.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/eihu0F/asdf-extras/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [BuffieLead](https://github.com/eihu0F/)

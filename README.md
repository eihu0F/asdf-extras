<div align="center">

# asdf-asdf-extras [![Build](https://github.com/eihu0F/asdf-asdf-extras/actions/workflows/build.yml/badge.svg)](https://github.com/eihu0F/asdf-asdf-extras/actions/workflows/build.yml) [![Lint](https://github.com/eihu0F/asdf-asdf-extras/actions/workflows/lint.yml/badge.svg)](https://github.com/eihu0F/asdf-asdf-extras/actions/workflows/lint.yml)

[asdf-extras](https://github.com/eihu0F/asdf-extras) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

**TODO: adapt this section**

- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).
- `SOME_ENV_VAR`: set this environment variable in your shell config to load the correct version of tool x.

# Install

Plugin:

```shell
asdf plugin add asdf-extras
# or
asdf plugin add asdf-extras https://github.com/eihu0F/asdf-asdf-extras.git
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

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/eihu0F/asdf-asdf-extras/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [BuffieLead](https://github.com/eihu0F/)

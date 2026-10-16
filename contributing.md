# Contributing

Testing Locally:

```shell
asdf plugin test <plugin-name> <plugin-url> [--asdf-tool-version <version>] [--asdf-plugin-gitref <git-ref>] [test-command*]

asdf plugin test asdf-extras https://github.com/eihu0F/asdf-extras.git "asdf-extras --help"
```

Tests are automatically run in GitHub Actions on push and PR.

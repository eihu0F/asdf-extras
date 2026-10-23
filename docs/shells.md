# Shell setup and completion

[Back to README](../README.md#shell-support)

Choose the section for your shell and copy its **Recommended setup** into the
startup file indicated. This enables `asdf update`, scoped `asdf install`, and
Tab completion for both `asdf` and `asdf-extras`. Start a new shell afterward.
If asdf is not on PATH yet, complete the
[asdf installation steps](https://asdf-vm.com/guide/getting-started.html) first.

Each section also provides a **Completion without command wrappers** alternative.
Choose that instead of initialization if you only want completion, not command
extensions. Do not copy both alternatives.

## Contents

- [Bash](#bash)
- [Zsh](#zsh)
- [Fish](#fish)
- [Elvish](#elvish)
- [Nushell](#nushell)
- [Which completion command should I use?](#which-completion-command-should-i-use)
- [Completion behavior details](#completion-behavior-details)
- [Shell refresh after updates](#shell-refresh-after-updates)

## Bash

### Recommended setup

Add to `~/.bashrc`:

```bash
eval "$(asdf-extras init bash)"
```

Open a new Bash session. Type `asdf update --` and press Tab to list update flags.
Type `asdf-extras ` and press Tab to list its subcommands.
Ensure your login-shell configuration loads `~/.bashrc` if needed.

Native asdf completion alone uses:

```bash
eval "$(asdf completion bash)"
```

If this line is already in your configuration, keep it **before** the `init`
line. Otherwise, no separate native completion line is needed: `init` loads it.
After initialization, the same `asdf completion bash` command generates combined
completion for both commands, so you can run it again to reload completion.
Do not omit `bash`: `asdf completion` and `asdf-extras completion` require a
shell name.

### Completion without command wrappers

To complete both `asdf` and `asdf-extras` without changing command behavior,
use this in `~/.bashrc` **instead of** the recommended setup:

```bash
eval "$(asdf-extras completion --asdf bash)"
```

This loads native asdf completion if none is registered.
To complete **only** `asdf-extras`, leaving native asdf completion untouched:

```bash
eval "$(asdf-extras completion bash)"
```

## Zsh

### Recommended setup

Add to `~/.zshrc`:

```zsh
autoload -Uz compinit
compinit
eval "$(asdf-extras init zsh)"
```

If Oh My Zsh or another framework already runs `compinit`, keep that existing
setup and add only the final line **after** it. Native asdf completion is loaded
automatically if no handler is registered.
Open a new Zsh session, type `asdf update --`, and press Tab.

### Completion without command wrappers

Use this in `~/.zshrc` instead of the recommended setup:

```zsh
autoload -Uz compinit
compinit
eval "$(asdf-extras completion --asdf zsh)"
```

With a framework, keep its completion setup and add only the final line after it.
To complete only `asdf-extras`, replace the final line with:

```zsh
eval "$(asdf-extras completion zsh)"
```

## Fish

### Recommended setup

Add to `~/.config/fish/config.fish`, after any native asdf setup:

```fish
asdf-extras init fish | source
```

Open a new Fish session, type `asdf update --`, and press Tab.
Existing native completion rules are retained; if no rules exist, initialization
loads them automatically.

### Completion without command wrappers

Use this in `~/.config/fish/config.fish` instead of initialization:

```fish
asdf-extras completion --asdf fish | source
```

To complete only `asdf-extras`, use:

```fish
asdf-extras completion fish | source
```

## Elvish

Requires **Elvish 0.21.0 or newer** and an interactive editor for completion.
Complete the native Elvish setup in the
[asdf getting-started guide](https://asdf-vm.com/guide/getting-started.html)
first. Native completion can depend on variables and helpers from that setup.

### Recommended setup

Add to `rc.elv`, **after** native asdf setup and completion registration:

```elvish
var asdf~ = $nil
eval (asdf-extras init elvish | slurp) &on-end={|ns| set asdf~ = $ns[asdf~]}
```

The callback makes the generated `asdf` wrapper available outside `eval`.
Open a new interactive Elvish session, type `asdf update --`, and press Tab.

### Completion without command wrappers

Use this in `rc.elv`, after native setup, instead of initialization:

```elvish
eval (asdf-extras completion --asdf elvish | slurp)
```

To complete only `asdf-extras`, without needing native asdf completion setup:

```elvish
eval (asdf-extras completion elvish | slurp)
```

## Nushell

Requires **Nushell 0.116.1 or newer**. Nushell resolves source paths and command
definitions at parse time, so generate a file first and then source it.

### Recommended setup

Run once in Nushell:

```nu
^asdf-extras init nushell | save --force ~/.asdf-extras-init.nu
```

Add to `config.nu` (find its path with `$nu.config-path`):

```nu
source ~/.asdf-extras-init.nu
```

Load any existing native asdf module **before** this line, not afterward.
The generated file already includes native and asdf-extras completion.
Open a new session, type `asdf update --`, and press Tab.
After changing the installed runtime, rerun the generation command and start a
new session.

### Completion without command wrappers

Run this instead of generating the initialization file:

```nu
^asdf-extras completion --asdf nushell | save --force ~/.asdf-extras-completion.nu
```

Then add this to `config.nu` instead of the initialization source line:

```nu
source ~/.asdf-extras-completion.nu
```

For `asdf-extras` completion only, generate the same file without `--asdf`:

```nu
^asdf-extras completion nushell | save --force ~/.asdf-extras-completion.nu
```

Use the same completion source line, then start a new session.
Regenerate saved completion files after changing the runtime.

## Which completion command should I use?

| Goal | Command that generates the shell code |
| --- | --- |
| Command extensions and completion for both commands (recommended) | `asdf-extras init <shell>` |
| Completion for both commands, without command wrappers | `asdf-extras completion --asdf <shell>` |
| Completion for `asdf-extras` only; leave native asdf registration untouched | `asdf-extras completion <shell>` |
| Reload both commands' completion after initialization | `asdf completion <shell>` |
| Native asdf completion only, without initialization | `asdf completion <shell>` |

Replace `<shell>` with `bash`, `zsh`, `fish`, `elvish`, or `nushell`.
These commands **print shell code**; running them alone does not enable
completion. Load the output using your shell's sample above.
Initialization already loads completion, so do not add an extra completion
command to an initialized setup.

## Completion behavior details

### Shared behavior

- Completion includes subcommands, shell names, scopes, update targets, plugins,
  and versions.
- The `asdf` overlay adds update and install extensions while preserving upstream
  definitions and delegating ordinary commands to native completion.
- Scope flags may appear between arguments. Scoped install delegation retains
  arguments after the cursor as well as before it.
- Update completion offers unselected scope flags after `--all`, while excluding
  incompatible targets and positional arguments.
- Repeated loading does not duplicate registrations or stack wrappers.
- Native completion loading and candidate-query failures are reported rather than
  silently replaced with empty results.

### Bash, Zsh, and Fish

- Bash discovers the native function with `complete -p asdf` and retains its
  registration options. External-command (`-C`) or other non-function
  registrations are left unchanged with an explicit error.
- Zsh retains the handler registered by `compinit` or a framework. If a framework
  replaces it later, run asdf-extras setup again.
- Fish adds conditional rules without erasing native registrations.
- If no native registration exists, combined setup loads native completion.

### Elvish

- Combined mode retains the function registered in
  `$edit:completion:arg-completer[asdf]`. If a framework replaces it later, run
  asdf-extras setup again.
- If no function is registered, asdf-extras evaluates `asdf completion elvish`
  unchanged and retains its registered handler or exported `arg-completer`.
- Generation errors, empty output, compilation failures, missing handlers, and
  non-function registrations are explicit errors, not empty-result fallbacks.
- Native rich candidate values and failures are preserved. Scoped install
  completion removes completed scope arguments before native delegation.
  Elvish supplies decoded arguments, including quoted plugin/version names.
- An existing handler retains its original setup context during delegation.
  Automatic loading runs in the asdf-extras module's evaluation context and does
  not inherit variables from `rc.elv`. If prerequisites cannot be resolved, load
  and register the native completer in its required context before asdf-extras.
- Failure in an unconfigured session does not by itself establish an upstream
  defect. asdf-extras does not repair or copy upstream completion logic.
  Standalone `asdf-extras` completion needs no native setup.

### Nushell

- Combined mode embeds `asdf completion nushell` output unchanged and imports its
  definitions before the asdf-extras overlay. Importing a native module afterward
  replaces the asdf-extras signatures.
- The generated module is the native baseline. Native commands such as
  `asdf plugin list` retain structured return values.
- Private aliases retain native root/install signatures for completion
  delegation; asdf-extras does not copy upstream completers.
- Only root, install, update, and completion signatures are extended.
  Initialized wrappers route extended commands to asdf-extras.
- Standalone completion does not load the native module.

## Shell refresh after updates

| Invocation | When the selected asdf-extras runtime changes |
| --- | --- |
| Initialized Bash/Zsh/Fish `asdf update` | Automatically reloads asdf-extras initialization and its completion overlay; retains native completion definitions |
| Initialized Elvish/Nushell `asdf update` | Prints a reminder after every update, including failures, to start a new session if asdf-extras changed; does not reload current definitions |
| Direct `asdf-extras update` | No automatic shell refresh |

The Bash/Zsh/Fish wrapper resolves the new executable with
`asdf which asdf-extras`, not the old shim or dispatcher. It reloads when the
selected executable path changes, keeping the current shell usable after cleanup
removes the old runtime.

If a bulk update fails but changes the selected runtime, initialization is still
refreshed and the update's failure status is preserved. If the runtime is
unchanged, no initialization is evaluated. Refresh failures report an error and
return nonzero. Startup configuration files are never rewritten.
For Elvish/Nushell, a new session reloads startup initialization without
referencing a removed runtime.

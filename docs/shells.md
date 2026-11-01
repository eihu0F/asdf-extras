# Shell setup and completion

[Back to README](../README.md#shell-support)

Choose the section for your shell and copy its **Recommended setup** into the
startup file indicated. Initialization (`asdf-extras init <shell>`) enables
`asdf update`, `asdf get`, `asdf shell` and scoped `asdf install`. The `asdf completion <shell>` line that
follows it enables Tab completion for both `asdf` and `asdf-extras`. Keep them in
this order, and start a new shell afterward.
If asdf is not on PATH yet, complete the
[asdf installation steps](https://asdf-vm.com/guide/getting-started.html) first.

Initialization does not load completion. Before initialization, `asdf completion
<shell>` prints native asdf completion; after initialization, the wrapper routes
the same command to combined completion for both commands.

Each section also provides a **Completion without command wrappers** alternative.
Choose that instead of initialization if you only want completion, not command
extensions. Do not copy both alternatives.

## Contents

- [Bash](#bash)
- [Zsh](#zsh)
- [Fish](#fish)
- [Elvish](#elvish)
- [Nushell](#nushell)
- [Session version overrides](#session-version-overrides)
- [Which completion command should I use?](#which-completion-command-should-i-use)
- [Completion behavior details](#completion-behavior-details)
- [Shell refresh after updates](#shell-refresh-after-updates)

## Bash

### Recommended setup

Add to `~/.bashrc`:

```bash
eval "$(asdf-extras init bash)"
eval "$(asdf completion bash)"
```

Open a new Bash session. Type `asdf update --` and press Tab to list update flags.
Type `asdf-extras ` and press Tab to list its subcommands.
Ensure your login-shell configuration loads `~/.bashrc` if needed.

The second line must come **after** `init`: before initialization, `asdf
completion bash` prints native asdf completion only. If your configuration already
has that line, keep it before `init` and add the line again after it. Otherwise,
no separate native completion line is needed: combined completion loads native
completion when none is registered. Run `asdf completion bash` again to reload
completion. Do not omit `bash`: `asdf completion` requires a shell name.

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
eval "$(asdf completion zsh)"
```

If Oh My Zsh or another framework already runs `compinit`, keep that existing
setup and add only the final two lines **after** it. Combined completion loads
native asdf completion if no handler is registered.
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
asdf completion fish | source
```

Open a new Fish session, type `asdf update --`, and press Tab.
Existing native completion rules are retained; if no rules exist, combined
completion loads them automatically.

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
eval (asdf completion elvish | slurp)
```

The callback makes the generated `asdf` wrapper available outside `eval`, so the
second line reaches combined completion instead of native completion.
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
The initialization file does not include completion. Start a new session so the
`asdf` wrapper is loaded, then generate the completion file once. Because it is
generated through the initialized wrapper, it also redefines the wrapper commands
so that they keep their completions:

```nu
asdf completion nushell | save --force ~/.asdf-extras-completion.nu
```

Add this line to `config.nu` **after** the initialization source line, then start
another new session:

```nu
source ~/.asdf-extras-completion.nu
```

Type `asdf update --` and press Tab.
After changing the installed runtime, rerun both generation commands and start a
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

## Session version overrides

`asdf shell <plugin> <version>...` and `asdf shell --unset <plugin>` need no setup
beyond the initialization above. A child process cannot change its parent's
environment, so each initialized wrapper changes the variable in its own shell:

| Shell | Set | Unset |
| --- | --- | --- |
| Bash, Zsh | `export ASDF_<TOOL>_VERSION=...` | `unset ASDF_<TOOL>_VERSION` |
| Fish | `set -gx ASDF_<TOOL>_VERSION ...` | `set -e -g ASDF_<TOOL>_VERSION` |
| Elvish | `set-env ASDF_<TOOL>_VERSION ...` | `unset-env ASDF_<TOOL>_VERSION` |
| Nushell | `load-env {ASDF_<TOOL>_VERSION: ...}` | `hide-env ASDF_<TOOL>_VERSION` |

Nushell's wrapper is `def --env`, so the change reaches the calling scope. With the
standalone `asdf-extras shell`, or without initialization, the override cannot be
applied; set the variable yourself in your shell's syntax from the table. Reloading
initialization again is safe and does not change existing overrides.

## Which completion command should I use?

| Goal | Command that generates the shell code |
| --- | --- |
| Command extensions (`asdf update`, `asdf get`, `asdf shell`, scoped `asdf install`) | `asdf-extras init <shell>` |
| Completion for both commands, after initialization (recommended); also reloads it | `asdf completion <shell>` |
| Completion for both commands, without initialization | `asdf-extras completion --asdf <shell>` |
| Completion for `asdf-extras` only; leave native asdf registration untouched | `asdf-extras completion <shell>` |
| Native asdf completion only, without initialization | `asdf completion <shell>` |

Replace `<shell>` with `bash`, `zsh`, `fish`, `elvish`, or `nushell`.
These commands **print shell code**; running them alone does not enable
completion. Load the output using your shell's sample above.
`asdf completion <shell>` means different things before and after initialization:
the initialized wrapper routes it to `asdf-extras completion --asdf <shell>`,
while without initialization it is native asdf's command. Use
`asdf-extras completion` directly only when you do not initialize.

## Completion behavior details

### Shared behavior

- Completion includes subcommands, shell names, scopes, update targets, plugins,
  and versions.
- The `asdf` overlay adds update, get, shell and install extensions while preserving upstream
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
- If no native registration exists, combined completion loads native completion.

### Elvish

- Combined mode retains the function registered in
  `$edit:completion:arg-completer[asdf]`. If a framework replaces it later, run
  asdf-extras setup again.
- If no function is registered, asdf-extras evaluates native `asdf completion elvish`
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

- Combined mode embeds native `asdf completion nushell` output unchanged and imports its
  definitions before the asdf-extras overlay. Importing a native module afterward
  replaces the asdf-extras signatures.
- The generated module is the native baseline. Native commands such as
  `asdf plugin list` retain structured return values.
- Private aliases retain native root/install signatures for completion
  delegation; asdf-extras does not copy upstream completers.
- Only root, install, update, get, shell, and completion signatures are extended.
  Initialized wrappers route extended commands to asdf-extras.
- Standalone completion does not load the native module.

## Shell refresh after updates

| Invocation | When the selected asdf-extras runtime changes |
| --- | --- |
| Initialized Bash/Zsh/Fish `asdf update` | Nothing to reload: the `asdf` wrapper is a fixed stub that calls the selected runtime on every call. Completion keeps working and a new shell loads its changed definitions |
| Initialized Elvish/Nushell `asdf update` | The session keeps working. Prints a note after every update, including failures, that a new session loads changed definitions if asdf-extras changed |
| Direct `asdf-extras update` | No shell change is needed or made |

The initialized Bash/Zsh/Fish `asdf` function holds no behavior of its own. Every call
resolves the selected runtime with `asdf which asdf-extras` and runs
`asdf-extras invoke`, which decides what to do: an asdf-extras command, or native asdf.
Standard input, output, error and the exit status pass through unchanged. If no runtime
can be resolved (asdf-extras is not installed or not selected), the call runs native
asdf, so recovery commands such as `asdf install asdf-extras` keep working. Output
generated from the plugin checkout calls `asdf cmd asdf-extras invoke` instead.

A process cannot change its parent shell, so `invoke` asks the wrapper to do it through
an extra file descriptor, named by `ASDF_EXTRAS_CONTROL_FD`, that the wrapper reads after
the command ends. No temporary file is involved: the wrapper captures the descriptor
(a pipe) while standard input, output and error stay connected to the terminal. The first
line, `handled`, proves that `invoke` ran; without it the wrapper runs native asdf. The
other lines are `set <NAME> <VALUE>` and `unset <NAME>` for `ASDF_*` environment variables,
which the wrapper applies only when the command succeeded. Anything else is ignored. This is
how `asdf shell` works. Only `asdf shell` keeps the descriptor open for the command it runs,
so background processes started by other commands cannot hold the wrapper up.

Completion in Bash, Zsh and Fish works the same way. The registered completion is fixed
glue that sends the command line to `asdf-extras invoke --complete`. The runtime answers
with candidates and with whether native completion should run (as typed, without some
words such as the scope flags of `install`, or not at all). Only the glue can run native
completion, because it is shell code, so the glue does that and merges the results.
Native definitions are kept. Without a resolvable runtime, only native completion runs.

Because the behavior lives in the runtime, changing it does not require reloading running
shells. The wrapper and the completion glue are meant to change rarely; a change to them
is picked up by a new shell. Startup configuration files are never rewritten. Elvish and
Nushell still use definitions with their own logic; a new session loads changed
definitions there.

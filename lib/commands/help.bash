#!/usr/bin/env bash

extras_maybe_help() {
	local topic="$1" arg
	shift
	for arg in "$@"; do
		if [[ "$arg" == --help || "$arg" == -h ]]; then
			case "$topic" in
			install) extras_help_install ;;
			update) extras_help_update ;;
			completion) extras_help_completion ;;
			esac
			exit 0
		fi
	done
}

extras_help_scopes() {
	cat <<'EOF'
Scopes (install and update):
  --home, -u    Home configuration (default); update removes replaced versions
  --parent, -p  Closest existing parent configuration; keep previous versions
  --local       Current directory configuration; keep previous versions
  Scope options cannot be combined. Home/local files are created when needed.
  Parent scope fails if no parent configuration exists.
  Scopes have no effect when tool versions are not being updated.
  Explicitly scoped bulk version updates only process plugins listed in that scope file.
EOF
}

extras_help_install() {
	cat <<'EOF'
asdf-extras install extensions:
  asdf install [--home|-u|--parent|-p|--local] <plugin> <version>
  asdf-extras install [--home|-u|--parent|-p|--local] <plugin> <version>

  With init, a scope flag routes install through extras; unscoped install is native.
  Direct extras install defaults to --home.
  Extras resolves latest or latest:<prefix>, installs, then activates the version
  in the selected .tool-versions file and verifies activation.
  Installation failure leaves the existing configuration unchanged.
  Install does not remove previous versions.

Examples:
  asdf install --home nodejs latest
  asdf install --parent nodejs 24.11.0
  asdf install --local nodejs latest:24

EOF
	extras_help_scopes
}

extras_help_update() {
	cat <<'EOF'
asdf-extras update:
  asdf update [--all | --asdf --plugin --version] [scope] [<plugin> [version]]
  asdf-extras update [--all | --asdf --plugin --version] [scope] [<plugin> [version]]

Update targets:
  --all         Update asdf itself, plugin definitions and tool versions
  --asdf        Update asdf itself to the latest stable release
  --plugin      Update plugin definitions
  --version     Update tool versions
  Combine target flags except --all. Use --all, not positional "all".
  --all does not accept a plugin or version.
  A version requires --version when selecting explicit targets.
  With no targets, a plugin/scope selects plugin and version updates.
  With no arguments, update is equivalent to update --all.
  An omitted version resolves to latest.
  Bulk updates skip plugins whose latest version cannot be resolved, with a warning.
  Other failures do not stop subsequent plugins; any failure returns nonzero.
  Plugins are processed sequentially, with activation verified before cleanup.
  Previously configured versions are removed only after successful installation
  and verified activation in home scope. Parent/local updates retain previous versions.
  Custom asdf updater: ${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras/update-asdf.bash
  Otherwise detect Homebrew, or update an owned standalone binary under HOME.
  Standalone updates require jq and SHA-256 verification.
  Initialized Bash/Zsh/Fish refresh extras after its runtime changes.
  Elvish/Nushell require a new session if extras changed; a reminder is printed.

Examples:
  asdf update
  asdf update nodejs
  asdf update --version --local nodejs latest:24
  asdf update --plugin

EOF
	extras_help_scopes
}

extras_help_completion() {
	cat <<'EOF'
asdf-extras completion:
  asdf completion [--asdf] <bash|zsh|fish|elvish|nushell>
  asdf-extras completion [--asdf] <bash|zsh|fish|elvish|nushell>

  Standalone extras defaults to completion for asdf-extras only.
  --asdf adds the native asdf overlay without installing command wrappers.
  Initialized asdf completion automatically enables --asdf.
  init enables command wrappers and completion for both commands.
  Nushell requires >= 0.116.1; save generated output and source it.
  Elvish requires >= 0.21.0 and an interactive editor.
  Configure native completion before extras init; see README for shell setup.
  --help, -h    Show this help without generating completion code.
EOF
}

extras_help_summary() {
	cat <<'EOF'

asdf-extras extensions (enabled by init):
  asdf update [targets] [scope] [<plugin> [version]]
    No arguments updates asdf, plugins and tools (--all).
  asdf install [--home|-u|--parent|-p|--local] <plugin> <version>
    Scoped install also activates the version; unscoped install stays native.
  asdf completion <bash|zsh|fish|elvish|nushell>
    Includes native completion and extras extensions.
  asdf update --help / asdf install --help / asdf completion --help
    Show extras targets, scopes, defaults, safety behavior and completion modes.
EOF
}

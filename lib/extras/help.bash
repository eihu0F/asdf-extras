#!/usr/bin/env bash

extras_maybe_help() {
	local topic="$1" arg
	shift
	for arg in "$@"; do
		if [[ "$arg" == --help || "$arg" == -h ]]; then
			case "$topic" in
			install) extras_help_install ;;
			update) extras_help_update ;;
			prune) extras_help_prune ;;
			get) extras_help_get ;;
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
  asdf update [--all | --asdf --plugin --version] [--use-latest] [scope] [<plugin> [version]]
  asdf-extras update [--all | --asdf --plugin --version] [--use-latest] [scope] [<plugin> [version]]

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
  Without --use-latest, an omitted version uses ASDF_EXTRAS_UPDATE_DEFAULT_VERSION
  (default: latest). ASDF_EXTRAS_UPDATE_DEFAULT_VERSION_<PLUGIN> overrides it.
  <PLUGIN> uses uppercase plugin name with non-alnum converted to _.
  With --use-latest (or ASDF_EXTRAS_UPDATE_USE_LATEST), value is a latest prefix.
  ASDF_EXTRAS_UPDATE_USE_LATEST_<PLUGIN> can enable/disable this per plugin.
  Omitted prefix uses ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX (default: empty).
  ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX_<PLUGIN> overrides it per plugin.
  Bulk updates skip plugins whose latest version cannot be resolved, with a warning.
  Other failures do not stop subsequent plugins; any failure returns nonzero.
  Plugins are processed sequentially, with activation verified before cleanup.
  Previously configured versions are removed only after successful installation
  and verified activation in home scope. Parent/local updates retain previous versions.
  Home-scoped bulk tool updates process extras last to keep its runtime available.
  ASDF_EXTRAS_PLUGIN_NAME selects its plugin name (default: asdf-extras).
  Custom asdf updater: ${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras/update-asdf.bash
  Otherwise detect Homebrew, or update an owned standalone binary under HOME.
  Standalone updates require jq and SHA-256 verification.
  Initialized Bash/Zsh/Fish refresh extras (and enabled completion) after its runtime changes.
  Elvish/Nushell require a new session if extras changed; a reminder is printed.

Examples:
  asdf update
  asdf update nodejs
  asdf update --version --local nodejs latest:24
  asdf update --plugin

EOF
	extras_help_scopes
}

extras_help_prune() {
	cat <<'EOF'
asdf-extras prune:
  asdf-extras prune [<plugin>]

  Remove installed versions that are not configured in the home .tool-versions.
  With no plugin argument, every installed plugin is checked; plugins absent
  from the home configuration have all their installed versions removed.
  With a plugin argument, only that plugin is checked.
  All versions configured for a plugin are retained, including fallback versions.
  A missing or unreadable home configuration stops pruning.
  Uninstall failures are reported; pruning continues for remaining versions.
  Prune uninstalls versions immediately without a confirmation prompt or dry run.

Examples:
  asdf-extras prune
  asdf-extras prune nodejs
  asdf-extras prune --help
EOF
}

extras_help_get() {
	cat <<'EOF'
asdf-extras get:
  asdf get [--home|-u|--parent|-p|--local] [<plugin>]
  asdf-extras get [--home|-u|--parent|-p|--local] [<plugin>]

  Read-only. Prints the versions configured in one .tool-versions file, in their
  original order and including fallbacks such as system, as one space-separated line.
  Reads only the selected file: it ignores ASDF_<TOOL>_VERSION overrides and never
  falls back to another file. Installation status is not checked.
  Direct extras get defaults to --home. Scope options cannot be combined.
  Honors ASDF_DEFAULT_TOOL_VERSIONS_FILENAME.
  Without a plugin, prints every configured entry as "<plugin> <versions>", one per line.
  The existing native asdf current is unchanged.

Exit status:
  0  Success (a missing home/local file lists nothing)
  1  Error: invalid arguments, or no parent configuration exists for --parent
  2  The plugin has no version configured in the selected file

Examples:
  asdf get nodejs
  asdf get --parent python
  asdf get --local
EOF
}

extras_help_completion() {
	cat <<'EOF'
asdf-extras completion:
  asdf completion [--asdf] <bash|zsh|fish|elvish|nushell>
  asdf-extras completion [--asdf] <bash|zsh|fish|elvish|nushell>

  Standalone extras defaults to completion for asdf-extras only.
  --asdf adds the native asdf overlay without installing command wrappers.
  Initialized asdf completion automatically enables --asdf.
  init enables command wrappers only; it does not load completion.
  Initialized Bash/Zsh/Fish reload enabled completion after an extras update.
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
  asdf get [--home|-u|--parent|-p|--local] [<plugin>]
    Prints the versions configured in one scope file without changing it.
  asdf-extras prune
    Removes installed versions not used by the home configuration.
  asdf completion <bash|zsh|fish|elvish|nushell>
    Includes native completion and extras extensions.
  asdf update --help / asdf install --help / asdf get --help / asdf-extras prune --help
    Show update, install, get and prune behavior and safety details.
  asdf completion --help
    Show extras targets, scopes, defaults, safety behavior and completion modes.
EOF
}

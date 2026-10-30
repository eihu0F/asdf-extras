#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
extras_lib=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

# shellcheck source=../help.bash
source "${extras_lib}/help.bash"

if [[ "${1:-}" == --asdf ]]; then
	shift
	case "${1:-}" in
	install)
		command asdf install --help
		printf '\n'
		extras_help_install
		;;
	update) extras_help_update ;;
	prune) extras_help_prune ;;
	get) extras_help_get ;;
	shell) extras_help_shell ;;
	setup) extras_help_setup ;;
	completion) extras_help_completion ;;
	*)
		command asdf "$@"
		if [[ "$#" -eq 1 && ("$1" == help || "$1" == --help || "$1" == -h) ]]; then
			extras_help_summary
		fi
		;;
	esac
	exit 0
fi

if [[ "$#" -gt 0 ]]; then
	[[ "$#" -eq 1 ]] || extras_fail "help accepts at most one topic"
	case "$1" in
	install) extras_help_install ;;
	update) extras_help_update ;;
	prune) extras_help_prune ;;
	get) extras_help_get ;;
	shell) extras_help_shell ;;
	setup) extras_help_setup ;;
	completion) extras_help_completion ;;
	*) extras_fail "unknown help topic: $1 (expected install, update, get, shell, prune, setup or completion)" ;;
	esac
	exit 0
fi

version="$(extras_self_version)"

printf "asdf-extras %s\n\n" "$version"

cat <<'EOF'
Usage:
  asdf-extras <subcommand>
  asdf-extras --version

Fallback (when asdf-extras is not installed):
  asdf cmd asdf-extras <subcommand>

Subcommands:
  completion [--asdf] <bash|zsh|fish|elvish|nushell>
  get [--home|-u|--parent|-p|--local] [<plugin>]
  help [install|update|get|shell|prune|setup|completion]
  init <bash|zsh|fish|elvish|nushell>
  install [--home|-u|--parent|-p|--local] [--replace] <plugin> <version>...
  prune [<plugin>]
  setup [<version>]
  shell <plugin> <version>... | shell --unset <plugin>   (initialized asdf only)
	update [--all | --asdf --plugin --version] [--use-latest] [scope] [<plugin> [version]]
  version

Completion (Bash, Zsh, Fish, Elvish and Nushell):
  completion registers asdf-extras completion without enabling command wrappers.
  --asdf also registers the asdf completion overlay (without command wrappers).
  init enables command wrappers only; enable completion separately with the
  completion command (after init, asdf completion <shell>).
  Initialized asdf completion automatically selects --asdf mode.
  Nushell completion requires Nushell >= 0.116.1; save the output and source it.
  Elvish completion requires Elvish >= 0.21.0 in an interactive shell.
  Load existing native Elvish completion before init; see README for eval setup.

EOF
extras_help_install
printf '\n'
extras_help_update
printf '\n'
extras_help_get
printf '\n'
extras_help_shell
printf '\n'
extras_help_prune
printf '\n'
extras_help_setup
printf '\n'
extras_help_completion

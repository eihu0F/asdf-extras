#!/usr/bin/env bash

# Entry point of the initialized asdf wrapper: every asdf call of an initialized
# shell arrives here, so the routing lives in the runtime and the wrapper stays a
# fixed stub. Usage:
#   asdf-extras invoke --shell <shell> --protocol <n> -- <asdf arguments>...
#
# ASDF_EXTRAS_CONTROL names a file shared with the wrapper (control protocol 1).
# It is the only way to change the calling shell, which a process cannot do:
#   handled                 first line, written before anything else; without it
#                           the wrapper knows nothing ran and runs native asdf
#   set <NAME> <VALUE>      export an environment variable (VALUE has no newline)
#   unset <NAME>            remove an environment variable
# The wrapper applies the lines only when this process succeeded.

set -euo pipefail

# Every asdf call passes through here, so avoid spawning processes (such as dirname).
current_script_path=${BASH_SOURCE[0]}
commands_dir="${current_script_path%/*}"
extras_lib="${commands_dir%/*}"

control="${ASDF_EXTRAS_CONTROL:-}"
if [[ -n "$control" ]]; then
	printf 'handled\n' >"$control"
fi
# Commands started from here must not inherit the channel, except shell.
unset ASDF_EXTRAS_CONTROL

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

# Runs an extras subcommand in place of this process.
run() {
	local subcommand="$1"
	shift
	exec "$BASH" "${commands_dir}/${subcommand}.bash" "$@"
}

native() {
	exec asdf "$@"
}

has_help_flag() {
	local arg
	for arg in "$@"; do
		[[ "$arg" == --help || "$arg" == -h ]] && return 0
	done
	return 1
}

main() {
	local shell_name="" protocol=""
	while (($#)); do
		case "$1" in
		--shell)
			shell_name="${2:-}"
			shift $(($# > 1 ? 2 : 1))
			;;
		--protocol)
			protocol="${2:-}"
			shift $(($# > 1 ? 2 : 1))
			;;
		--)
			shift
			break
			;;
		*) extras_fail "invoke: unknown option: $1" ;;
		esac
	done
	case "$shell_name" in
	bash | zsh | fish | elvish | nushell) ;;
	*) extras_fail "invoke: unsupported shell: ${shell_name:-<none>}" ;;
	esac
	[[ "$protocol" =~ ^[0-9]+$ ]] || extras_fail "invoke: invalid protocol: ${protocol:-<none>}"

	local subcommand="${1:-}" arg
	case "$subcommand" in
	install | update | get | completion | shell)
		if has_help_flag "$@"; then
			run help --asdf "$@"
		fi
		;;
	esac

	case "$subcommand" in
	help | --help | -h) run help --asdf "$@" ;;
	completion)
		shift
		case "${1:-}" in
		bash | zsh | fish | nushell | elvish) run completion --asdf --wrappers "$@" ;;
		*) run completion "$@" ;;
		esac
		;;
	get)
		shift
		run get "$@"
		;;
	shell)
		shift
		ASDF_EXTRAS_CONTROL="$control" run shell "$@"
		;;
	update)
		shift
		run update "$@"
		;;
	install)
		shift
		for arg in "$@"; do
			case "$arg" in
			-u | --home | -p | --parent | --local) run install "$@" ;;
			esac
		done
		native install "$@"
		;;
	*) native "$@" ;;
	esac
}

main "$@"

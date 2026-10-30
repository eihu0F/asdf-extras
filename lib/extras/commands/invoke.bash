#!/usr/bin/env bash

# Entry point of the initialized asdf wrapper: every asdf call of an initialized
# shell arrives here, so the routing lives in the runtime and the wrapper stays a
# fixed stub. Usage:
#   asdf-extras invoke --shell <shell> --protocol <n> -- <asdf arguments>...
#   asdf-extras invoke --complete [--standalone] --cword <i> --shell <shell> \
#     --protocol <n> -- <command line words>...   (answers a completion stub)
#
# ASDF_EXTRAS_CONTROL_FD names an open file descriptor that the wrapper reads once
# this process ends (control protocol 1). It is the only way to change the calling
# shell, which a process cannot do, and it needs no file. Lines written to it:
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

# The channel exists only if the wrapper opened it for this process.
control_fd="${ASDF_EXTRAS_CONTROL_FD:-}"
if [[ "$control_fd" =~ ^[0-9]+$ ]] && { true >&"$control_fd"; } 2>/dev/null; then
	printf 'handled\n' >&"$control_fd"
else
	control_fd=""
fi
unset ASDF_EXTRAS_CONTROL_FD

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
	local shell_name="" protocol="" complete=0 standalone=0 cword=""
	while (($#)); do
		case "$1" in
		--complete)
			complete=1
			shift
			;;
		--standalone)
			standalone=1
			shift
			;;
		--cword)
			cword="${2:-}"
			shift $(($# > 1 ? 2 : 1))
			;;
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

	# Only shell uses the channel. Closing it elsewhere keeps the wrapper from waiting
	# for background processes that would otherwise inherit it.
	if [[ -n "$control_fd" && "${1:-}" != shell ]]; then
		eval "exec ${control_fd}>&-"
	fi

	if ((complete)); then
		[[ "$cword" =~ ^[0-9]+$ ]] || extras_fail "invoke: invalid cword: ${cword:-<none>}"
		# shellcheck source=../completion-candidates.bash
		source "${extras_lib}/completion-candidates.bash"
		if ((standalone)); then
			extras_completion_query --standalone "$cword" "$@"
		else
			extras_completion_query "$cword" "$@"
		fi
		return 0
	fi

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
		ASDF_EXTRAS_CONTROL_FD="$control_fd" run shell "$@"
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

#!/usr/bin/env bash

# Routes a subcommand received by a public entry point to its implementation.
# Usage: dispatch.bash <plugin|installed> [<subcommand>] [<args>...]

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
commands_dir="$(dirname "$current_script_path")/commands"

# Each entry point states its origin, so an inherited value never applies.
case "${1:-}" in
plugin | installed) export ASDF_EXTRAS_ORIGIN="$1" ;;
*)
	printf "asdf-extras: invalid entry point origin: %s\n" "${1:-}" >&2
	exit 1
	;;
esac
shift

subcommand="${1:-}"
case "$subcommand" in
"")
	subcommand="help"
	set --
	;;
"-h" | "--help" | "help")
	subcommand="help"
	shift
	;;
"-v" | "--version")
	subcommand="version"
	set --
	;;
*)
	shift
	;;
esac

command_file="${commands_dir}/${subcommand}.bash"
if [[ "$subcommand" == */* || ! -f "$command_file" ]]; then
	printf "asdf-extras: unknown subcommand: %s\n" "$subcommand" >&2
	"$BASH" "${commands_dir}/help.bash" >&2
	exit 1
fi

exec "$BASH" "$command_file" "$@"

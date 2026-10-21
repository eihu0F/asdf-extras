#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
commands_dir=$(dirname "$current_script_path")

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

command_file="${commands_dir}/command-${subcommand}"
if [[ ! -x "$command_file" ]]; then
	printf "asdf-extras: unknown subcommand: %s\n" "$subcommand" >&2
	"${commands_dir}/command-help" >&2
	exit 1
fi

"$command_file" "$@"

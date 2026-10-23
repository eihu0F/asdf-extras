#!/usr/bin/env bash

set -euo pipefail

shell_name="${1:-bash}"
current_script_path=${BASH_SOURCE[0]}
extras_root="$(cd "$(dirname "$current_script_path")/../../.." && pwd)"
init_dir="${extras_root}/lib/init"
dispatcher_path="${extras_root}/lib/commands/dispatch.bash"

emit_source_line() {
	local shell="$1"
	local file_path="$2"
	local dispatcher="$3"

	case "$shell" in
	bash | zsh)
		printf "ASDF_EXTRAS_DISPATCHER=%q\n" "$dispatcher"
		printf "source %q\n" "$file_path"
		;;
	fish)
		printf "set -gx ASDF_EXTRAS_DISPATCHER '%s'\n" "$dispatcher"
		printf "source '%s'\n" "$file_path"
		;;
	elvish)
		printf "set-env ASDF_EXTRAS_DISPATCHER '%s'\n" "${dispatcher//\'/\'\'}"
		cat "$file_path"
		;;
	nushell)
		printf "\$env.ASDF_EXTRAS_DISPATCHER = '%s'\n" "$dispatcher"
		printf "source '%s'\n" "$file_path"
		;;
	*)
		printf "asdf-extras: unsupported shell: %s\n" "$shell" >&2
		exit 1
		;;
	esac
}

case "$shell_name" in
bash)
	emit_source_line "$shell_name" "${init_dir}/bash.sh" "$dispatcher_path"
	;;
zsh)
	emit_source_line "$shell_name" "${init_dir}/zsh.zsh" "$dispatcher_path"
	;;
fish)
	emit_source_line "$shell_name" "${init_dir}/fish.fish" "$dispatcher_path"
	;;
elvish)
	emit_source_line "$shell_name" "${init_dir}/elvish.elv" "$dispatcher_path"
	;;
nushell)
	emit_source_line "$shell_name" "${init_dir}/nushell.nu" "$dispatcher_path"
	;;
*)
	printf "asdf-extras: unsupported shell: %s\n" "$shell_name" >&2
	exit 1
	;;
esac

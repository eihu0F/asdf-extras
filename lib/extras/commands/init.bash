#!/usr/bin/env bash

set -euo pipefail

shell_name="${1:-bash}"
current_script_path=${BASH_SOURCE[0]}
extras_root="$(cd "$(dirname "$current_script_path")/../../.." && pwd)"
init_dir="${extras_root}/lib/init"

# shellcheck source=../common.bash
source "${extras_root}/lib/extras/common.bash"

# The wrappers reach extras through the entry point this init came from, not
# through a path inside this runtime.
origin="$(extras_origin)"

emit_source_line() {
	local shell="$1"
	local file_path="$2"

	case "$shell" in
	bash | zsh)
		printf "ASDF_EXTRAS_INIT_ORIGIN=%q\n" "$origin"
		printf "source %q\n" "$file_path"
		;;
	fish)
		printf "set -gx ASDF_EXTRAS_INIT_ORIGIN '%s'\n" "$origin"
		printf "source '%s'\n" "$file_path"
		;;
	elvish)
		printf "set-env ASDF_EXTRAS_INIT_ORIGIN '%s'\n" "$origin"
		cat "$file_path"
		;;
	nushell)
		printf "\$env.ASDF_EXTRAS_INIT_ORIGIN = '%s'\n" "$origin"
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
	emit_source_line "$shell_name" "${init_dir}/bash.sh"
	;;
zsh)
	emit_source_line "$shell_name" "${init_dir}/zsh.zsh"
	;;
fish)
	emit_source_line "$shell_name" "${init_dir}/fish.fish"
	;;
elvish)
	emit_source_line "$shell_name" "${init_dir}/elvish.elv"
	;;
nushell)
	emit_source_line "$shell_name" "${init_dir}/nushell.nu"
	;;
*)
	printf "asdf-extras: unsupported shell: %s\n" "$shell_name" >&2
	exit 1
	;;
esac

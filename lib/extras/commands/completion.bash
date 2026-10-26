#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
plugin_dir="$(cd "$(dirname "$current_script_path")/../../.." && pwd)"

# shellcheck source=../common.bash
source "${plugin_dir}/lib/extras/common.bash"

# Internal query used by the shell completion scripts. Everything after the
# flag belongs to the query, so it must be handled before help or option parsing.
if [[ "${1:-}" == --candidates ]]; then
	shift
	# shellcheck source=../completion-candidates.bash
	source "${plugin_dir}/lib/extras/completion-candidates.bash"
	extras_completion_candidates "$@"
	exit 0
fi

# shellcheck source=../help.bash
source "${plugin_dir}/lib/extras/help.bash"
extras_maybe_help completion "$@"

main() {
	local shell_name="" arg include_asdf=0 with_wrappers=0
	for arg in "$@"; do
		case "$arg" in
		--asdf) include_asdf=1 ;;
		--wrappers) with_wrappers=1 ;;
		-*) extras_fail "unknown completion option: $arg" ;;
		*)
			[[ -z "$shell_name" ]] || extras_fail "completion accepts only one shell"
			shell_name="$arg"
			;;
		esac
	done
	[[ -n "$shell_name" ]] || extras_fail "usage: asdf-extras completion [--asdf] <bash|zsh|fish|elvish|nushell>"
	if ((with_wrappers)); then
		# Passed by every initialized `asdf completion <shell>`: the init wrappers are
		# loaded. Only Nushell needs it, because it binds completers when a command
		# is defined, so the wrappers that init defined must be defined again.
		((include_asdf)) || extras_fail "--wrappers requires --asdf"
	fi

	# Completion queries go through the entry point this output came from, not
	# through a path inside this runtime.
	local origin
	origin="$(extras_origin)"

	case "$shell_name" in
	bash | zsh)
		printf 'ASDF_EXTRAS_COMPLETION_ORIGIN=%q\n' "$origin"
		printf 'source %q\n' "${plugin_dir}/lib/completion/asdf-extras.${shell_name}"
		if ((include_asdf)); then
			printf 'source %q\n' "${plugin_dir}/lib/completion/asdf.${shell_name}"
		fi
		;;
	fish)
		printf "set -gx ASDF_EXTRAS_COMPLETION_ORIGIN '%s'\n" "$origin"
		printf "source '%s'\n" "${plugin_dir}/lib/completion/asdf-extras.fish"
		if ((include_asdf)); then
			printf "source '%s'\n" "${plugin_dir}/lib/completion/asdf.fish"
		fi
		;;
	nushell)
		local native=""
		if ((include_asdf)); then
			native="$(command asdf completion nushell)" || extras_fail "could not generate native Nushell completion"
			[[ -n "$native" ]] || extras_fail "native Nushell completion is empty"
		fi
		printf "\$env.ASDF_EXTRAS_COMPLETION_ORIGIN = '%s'\n" "$origin"
		printf "source '%s'\n" "${plugin_dir}/lib/completion/asdf-extras.nu"
		if ((include_asdf)); then
			printf '%s\n' "$native"
			printf 'alias asdf-extras-native-root = asdf\n'
			printf 'alias asdf-extras-native-install = asdf install\n'
			printf "source '%s'\n" "${plugin_dir}/lib/completion/asdf.nu"
		fi
		if ((with_wrappers)); then
			printf "source '%s'\n" "${plugin_dir}/lib/init/nushell-completion.nu"
		fi
		;;
	elvish)
		local elvish_root="${plugin_dir//\'/\'\'}"
		printf "set-env ASDF_EXTRAS_COMPLETION_ORIGIN '%s'\n" "$origin"
		cat "${plugin_dir}/lib/completion/load.elv"
		printf "asdf-extras-load-completion '%s'\n" "${elvish_root}/lib/completion/asdf-extras"
		if ((include_asdf)); then
			printf "asdf-extras-load-completion '%s'\n" "${elvish_root}/lib/completion/asdf"
		fi
		;;
	*)
		extras_fail "unsupported shell: $shell_name"
		;;
	esac
}

main "$@"

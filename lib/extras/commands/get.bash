#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
extras_lib=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

# shellcheck source=../help.bash
source "${extras_lib}/help.bash"
extras_maybe_help get "$@"

main() {
	local arg scope="" file plugin="" versions
	local -a positional=()

	for arg in "$@"; do
		case "$arg" in
		-u | --home) scope="$(extras_select_scope "$scope" --home)" ;;
		-p | --parent) scope="$(extras_select_scope "$scope" --parent)" ;;
		--local) scope="$(extras_select_scope "$scope" --local)" ;;
		-*) extras_fail "unknown get option: $arg" ;;
		*) positional+=("$arg") ;;
		esac
	done
	[[ ${#positional[@]} -le 1 ]] || extras_fail "usage: asdf-extras get [--home|-u|--parent|-p|--local] [<plugin>]"
	[[ ${#positional[@]} -eq 0 ]] || plugin="${positional[0]}"

	file="$(extras_scope_file "${scope:---home}")"
	if [[ -z "$plugin" ]]; then
		extras_configured_entries "$file"
		return 0
	fi

	versions="$(extras_configured_version "$file" "$plugin")"
	if [[ -z "$versions" ]]; then
		# Status 2 tells a missing entry apart from usage and configuration errors (1).
		printf "asdf-extras: no version configured for %s in %s\n" "$plugin" "$file" >&2
		return 2
	fi
	printf '%s\n' "$versions"
}

main "$@"

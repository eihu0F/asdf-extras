#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
extras_lib=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

# shellcheck source=../help.bash
source "${extras_lib}/help.bash"
extras_maybe_help shell "$@"

# A child process cannot change its parent's environment. It asks the wrapper to
# do it through the control file (see invoke.bash). Without that channel, as when
# run directly, nothing can change, so never report success.
control="${ASDF_EXTRAS_CONTROL:-}"
if [[ -z "$control" ]]; then
	extras_fail "shell must run through an initialized shell; a separate process cannot change the calling shell (see: asdf-extras init <shell>, then: asdf shell <plugin> <version>)"
fi

main() {
	local usage="usage: asdf shell <plugin> <version>... | asdf shell --unset <plugin>"
	local plugin_pattern='^[A-Za-z0-9_][A-Za-z0-9_-]*$'
	local version_pattern='^[A-Za-z0-9][A-Za-z0-9._+:/@~^-]*$'
	local unset_override=0 plugin variable version versions=""

	if [[ "${1:-}" == "--unset" ]]; then
		unset_override=1
		shift
		(($# == 1)) || extras_fail "$usage"
	else
		(($# >= 2)) || extras_fail "$usage"
	fi
	plugin="$1"
	shift
	[[ "$plugin" =~ $plugin_pattern ]] || extras_fail "invalid plugin name: $plugin"
	for version in "$@"; do
		[[ "$version" =~ $version_pattern ]] || extras_fail "invalid version: $version"
		versions="${versions:+$versions }$version"
	done

	# The same normalization as native asdf: uppercase, with - as _.
	variable="ASDF_$(printf '%s' "$plugin" | LC_ALL=C tr '[:lower:]-' '[:upper:]_')_VERSION"
	if ((unset_override)); then
		printf 'unset %s\n' "$variable" >>"$control"
	else
		printf 'set %s %s\n' "$variable" "$versions" >>"$control"
	fi
}

main "$@"

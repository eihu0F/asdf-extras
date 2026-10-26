#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
extras_lib=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

# shellcheck source=../help.bash
source "${extras_lib}/help.bash"
extras_maybe_help setup "$@"

main() {
	local plugin="${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" version=latest

	[[ $# -le 1 ]] || extras_fail "usage: asdf-extras setup [<version>]"
	[[ $# -eq 0 ]] || version="$1"
	[[ "$version" != -* ]] || extras_fail "unknown setup option: $version"

	# Activation and failures are install's; setup only names the plugin and the home scope.
	extras_run install --home "$plugin" "$version"
}

main "$@"

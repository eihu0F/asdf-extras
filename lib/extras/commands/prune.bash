#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
extras_lib=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

# shellcheck source=../help.bash
source "${extras_lib}/help.bash"
extras_maybe_help prune "$@"

version_is_configured() {
	local configured="$1" version="$2" candidate
	local -a configured_versions=()
	read -r -a configured_versions <<<"$configured"
	for candidate in ${configured_versions[@]+"${configured_versions[@]}"}; do
		[[ "$candidate" == "$version" ]] && return 0
	done
	return 1
}

prune_plugin() {
	local plugin="$1" file="$2"
	local configured installed_output installed_versions version failed=0

	if ! configured="$(extras_configured_version "$file" "$plugin")"; then
		printf "asdf-extras: could not read home configuration for plugin: %s\n" "$plugin" >&2
		return 1
	fi
	if ! installed_output="$(command asdf list "$plugin")"; then
		printf "asdf-extras: could not list installed versions for plugin: %s\n" "$plugin" >&2
		return 1
	fi
	installed_versions="$(printf '%s\n' "$installed_output" |
		sed 's/^[[:space:]]*\*\{0,1\}[[:space:]]*//' |
		sed '/^$/d' |
		sed '/^No versions installed$/d' |
		sed '/^system$/d')"

	while IFS= read -r version; do
		[[ -n "$version" ]] || continue
		if version_is_configured "$configured" "$version"; then
			continue
		fi
		printf "asdf-extras: removing unused version: %s %s\n" "$plugin" "$version"
		if ! (command asdf uninstall "$plugin" "$version"); then
			printf "asdf-extras: failed to remove version: %s %s\n" "$plugin" "$version" >&2
			failed=1
		fi
	done <<<"$installed_versions"

	return "$failed"
}

main() {
	local file plugins installed_plugins plugin failed=0
	[[ $# -le 1 ]] || extras_fail "usage: asdf-extras prune [<plugin>]"
	plugin="${1:-}"
	[[ "$plugin" != -* ]] || extras_fail "usage: asdf-extras prune [<plugin>]"

	file="$(extras_scope_file --home)"
	[[ -r "$file" ]] || extras_fail "home configuration does not exist or is not readable: $file"
	if ! installed_plugins="$(command asdf plugin list)"; then
		extras_fail "could not list plugins"
	fi
	if [[ -z "${installed_plugins//[[:space:]]/}" && -z "$plugin" ]]; then
		printf "asdf-extras: no plugins installed\n"
		return 0
	fi

	if [[ -n "$plugin" ]]; then
		if ! grep -Fx -- "$plugin" <<<"$installed_plugins" >/dev/null; then
			extras_fail "plugin is not installed: $plugin"
		fi
		plugins="$plugin"
	else
		plugins="$installed_plugins"
	fi

	while IFS= read -r plugin; do
		[[ -n "$plugin" ]] || continue
		if ! prune_plugin "$plugin" "$file"; then
			failed=1
		fi
	done <<<"$plugins"

	if ((failed)); then
		printf "asdf-extras: pruning completed with errors\n" >&2
	else
		printf "asdf-extras: pruning complete\n"
	fi
	return "$failed"
}

main "$@"

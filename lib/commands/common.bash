#!/usr/bin/env bash

set -euo pipefail

extras_fail() {
	printf "asdf-extras: %s\n" "$*" >&2
	exit 1
}

extras_need_args() {
	local required="$1"
	local got="$2"
	local usage="$3"

	if ((got < required)); then
		extras_fail "usage: ${usage}"
	fi
}

extras_plugins() {
	command asdf plugin list 2>/dev/null || true
}

extras_installed_versions() {
	local plugin="$1"
	command asdf list "$plugin" 2>/dev/null |
		sed 's/^[[:space:]]*\*\{0,1\}[[:space:]]*//' |
		sed '/^$/d' |
		sed '/^No versions installed$/d' |
		sed '/^system$/d'
}

extras_has_installed_versions() {
	local plugin="$1"
	[[ -n "$(extras_installed_versions "$plugin")" ]]
}

extras_latest_version() {
	local plugin="$1"
	command asdf latest "$plugin" 2>/dev/null | head -n1 | awk '{print $NF}'
}

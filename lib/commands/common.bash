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

extras_current_version() {
	local plugin="$1"
	command asdf current "$plugin" 2>/dev/null |
		awk 'NR==2 {print $2}' |
		sed '/^Version$/d' |
		sed '/^$/d' |
		sed '/^system$/d'
}

extras_self_version() {
	local current_script_path extras_root version_file
	current_script_path=${BASH_SOURCE[0]}
	extras_root=$(dirname "$(dirname "$(dirname "$current_script_path")")")
	version_file="${extras_root}/version.txt"

	if [[ -d "${extras_root}/.git" ]]; then
		if git -C "$extras_root" rev-parse -q --verify HEAD >/dev/null 2>&1; then
			git -C "$extras_root" describe --tags --always --dirty
			return 0
		fi
	fi

	if [[ -s "$version_file" ]]; then
		head -n1 "$version_file"
		return 0
	fi

	printf "%s\n" "unknown"
}

#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
extras_lib=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

# shellcheck source=../help.bash
source "${extras_lib}/help.bash"
extras_maybe_help install "$@"

main() {
	local arg plugin version target file current merged replace=0 resolved
	local -a install_opts=()
	local -a positional=()
	local -a requested=() targets=() merged_versions=()
	local scope=""

	for arg in "$@"; do
		case "$arg" in
		-u | --home)
			scope="$(extras_select_scope "$scope" --home)"
			;;
		-p | --parent)
			scope="$(extras_select_scope "$scope" --parent)"
			;;
		--local)
			scope="$(extras_select_scope "$scope" --local)"
			;;
		--replace)
			replace=1
			;;
		-*)
			install_opts+=("$arg")
			;;
		*)
			positional+=("$arg")
			;;
		esac
	done

	# Bash 3.2 treats empty arrays as unset under nounset; guard their expansion.
	set -- ${positional[@]+"${positional[@]}"}
	extras_need_args 2 "$#" "asdf-extras install [options] <plugin> <version>..."

	plugin="$1"
	shift
	requested=("$@")
	scope="${scope:---home}"
	file="$(extras_scope_file "$scope")"
	for version in "${requested[@]}"; do
		target="$version"
		case "$version" in
		latest | latest:*)
			if [[ "$version" == latest ]]; then
				target="$(command asdf latest "$plugin")" ||
					extras_fail "unable to resolve latest version for plugin: $plugin"
			else
				target="$(command asdf latest "$plugin" "${version#latest:}")" ||
					extras_fail "unable to resolve latest version for plugin: $plugin"
			fi
			[[ -n "$target" ]] || extras_fail "unable to resolve latest version for plugin: $plugin"
			;;
		esac
		targets+=("$target")
	done
	# Read the selected file itself: a shadowing override must not pick the entry.
	current="$(extras_configured_version "$file" "$plugin")"
	merged="$(extras_merged_versions "$replace" "$current" "${targets[@]}")"
	read -r -a merged_versions <<<"$merged"

	resolved=1
	for target in "${targets[@]}"; do
		[[ "$target" == system ]] || extras_version_installed "$plugin" "$target" || resolved=0
	done
	if [[ "$current" == "$merged" ]] && ((resolved)); then
		printf "asdf-extras: %s already configured at %s (%s)\n" "$plugin" "$merged" "$file"
		return 0
	fi
	if [[ -z "$current" ]]; then
		printf "asdf-extras: installing %s %s\n" "$plugin" "$merged"
	else
		printf "asdf-extras: updating %s %s -> %s\n" "$plugin" "$current" "$merged"
	fi

	# system is a literal entry: it is never installed.
	for target in "${targets[@]}"; do
		[[ "$target" != system ]] || continue
		if ! (
			extras_prepare_install_environment "$plugin" "$target"
			command asdf install ${install_opts[@]+"${install_opts[@]}"} "$plugin" "$target"
		); then
			extras_fail "install failed for plugin: $plugin ($target)"
		fi
		extras_version_installed "$plugin" "$target" ||
			extras_fail "target version is not installed: $plugin ($target)"
	done
	if [[ "$scope" == --local ]]; then
		command asdf set "$plugin" "${merged_versions[@]}"
	else
		command asdf set "$scope" "$plugin" "${merged_versions[@]}"
	fi
	[[ "$(extras_configured_version "$file" "$plugin")" == "$merged" ]] ||
		extras_fail "target version was not set in $file: $plugin ($merged)"
}

main "$@"

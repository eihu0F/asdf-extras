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

extras_select_scope() {
	local previous="$1" requested="$2"
	if [[ -n "$previous" && "$previous" != "$requested" ]]; then
		extras_fail "--home, --parent and --local cannot be used together"
	fi
	printf "%s\n" "$requested"
}

extras_scope_file() {
	local scope="$1" directory filename
	filename="${ASDF_DEFAULT_TOOL_VERSIONS_FILENAME:-.tool-versions}"
	case "$scope" in
	--home) printf "%s/%s\n" "$HOME" "$filename" ;;
	--local) printf "%s/%s\n" "$PWD" "$filename" ;;
	--parent)
		directory="$(dirname "$PWD")"
		while :; do
			if [[ -f "$directory/$filename" ]]; then
				printf "%s/%s\n" "$directory" "$filename"
				return 0
			fi
			[[ "$directory" != / ]] || break
			directory="$(dirname "$directory")"
		done
		extras_fail "no ${filename} found in a parent directory"
		;;
	esac
}

extras_configured_version() {
	local file="$1" plugin="$2"
	[[ -f "$file" ]] || return 0
	awk -v plugin="$plugin" '
		$1 == plugin {
			for (i = 2; i <= NF && $i !~ /^#/; i++)
				printf "%s%s", (i == 2 ? "" : " "), $i
			print ""
			exit
		}
	' "$file"
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

extras_version_exists() {
	local plugin="$1"
	local version="$2"

	[[ -n "$version" ]] || return 1

	command asdf list all "$plugin" 2>/dev/null |
		sed 's/^[[:space:]]*//' |
		grep -Fx -- "$version" >/dev/null
}

extras_version_installed() {
	local plugin="$1"
	local version="$2"

	[[ -n "$version" ]] || return 1

	extras_installed_versions "$plugin" |
		grep -Fx -- "$version" >/dev/null
}

extras_plugin_env_suffix() {
	local plugin="$1"
	printf "%s\n" "$plugin" |
		tr '[:lower:]' '[:upper:]' |
		sed 's/[^A-Z0-9]/_/g'
}

extras_prepare_install_environment() {
	local plugin="$1"
	local version="${2:-}"
	local suffix data_dir env_dir default_env_file
	local env_file_var env_file
	local fn_var fn_name

	suffix="$(extras_plugin_env_suffix "$plugin")"
	data_dir="${ASDF_DATA_DIR:-$HOME/.asdf}"
	env_dir="${ASDF_EXTRAS_INSTALL_ENV_DIR:-${data_dir}/asdf-extras/install/env}"
	default_env_file="${env_dir}/${plugin}.env"

	env_file_var="ASDF_EXTRAS_INSTALL_ENV_FILE_${suffix}"
	env_file="${!env_file_var-}"
	if [[ -z "$env_file" ]]; then
		env_file="$default_env_file"
	fi

	if [[ -f "$env_file" ]]; then
		# shellcheck disable=SC1090
		source "$env_file"
	fi

	fn_var="ASDF_EXTRAS_INSTALL_ENV_FUNCTION_${suffix}"
	fn_name="${!fn_var-}"
	if [[ -z "$fn_name" ]]; then
		fn_name="${ASDF_EXTRAS_INSTALL_ENV_FUNCTION-}"
	fi
	if [[ -z "$fn_name" ]]; then
		return 0
	fi

	if ! declare -F "$fn_name" >/dev/null 2>&1; then
		extras_fail "install env function not found: ${fn_name} (plugin: ${plugin})"
	fi

	if ! "$fn_name" "$plugin" "$version"; then
		extras_fail "install env function failed: ${fn_name} (plugin: ${plugin})"
	fi
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

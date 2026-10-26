#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
extras_lib=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

# shellcheck source=../help.bash
source "${extras_lib}/help.bash"
extras_maybe_help update "$@"

update_one() {
	local plugin="$1" scope="$2" file="$3" old_primary target
	local previous=""
	local -a previous_versions=() install_args=("$scope")
	shift 3
	if ((update_versions)); then
		if ! previous="$(extras_configured_version "$file" "$plugin")"; then
			printf "asdf-extras: could not read configuration: %s\n" "$file" >&2
			return 1
		fi
	fi

	# Subshells allow Bash 3.2 to catch command builtin failures.
	if ((update_plugins)); then
		if ! (command asdf plugin update "$plugin"); then
			printf "asdf-extras: plugin update failed: %s\n" "$plugin" >&2
			return 1
		fi
	fi
	((update_versions)) || return 0
	((update_replace == 0)) || install_args+=(--replace)
	if ! (extras_run install "${install_args[@]}" "$plugin" "$@"); then
		printf "asdf-extras: update failed; previous installation retained: %s\n" "$plugin" >&2
		return 1
	fi

	if [[ "$scope" == --home ]]; then
		if ! target="$(extras_configured_version "$file" "$plugin")" || [[ -z "$target" ]]; then
			printf "asdf-extras: could not verify configuration; previous versions retained: %s\n" "$plugin" >&2
			return 1
		fi
		# Only the replaced primary is cleaned up, and only when the resulting
		# list no longer keeps it. Fallbacks dropped by a replacement stay installed.
		read -r -a previous_versions <<<"$previous"
		old_primary="${previous_versions[0]-}"
		[[ -n "$old_primary" && "$old_primary" != system ]] || return 0
		case "$old_primary" in
		path:* | ref:*) return 0 ;;
		esac
		case " $target " in
		*" $old_primary "*) return 0 ;;
		esac
		if ! (command asdf uninstall "$plugin" "$old_primary"); then
			printf "asdf-extras: failed to remove previous version: %s (%s)\n" "$plugin" "$old_primary" >&2
			return 1
		fi
	fi
}

main() {
	local arg scope="" explicit_scope=0 file plugins plugin
	local extras_plugin="${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}"
	local update_asdf=0 update_plugins=0 update_versions=0 selected=0 all=0 failed=0
	local force_use_latest=0 global_use_latest=0 update_replace=0
	local -a positional=()
	local plugin_env_suffix plugin_version_var plugin_prefix_var plugin_use_latest_var
	local implicit_version implicit_prefix candidate_version
	local use_latest_for_plugin element
	local -a targets=() elements=()

	if [[ "${ASDF_EXTRAS_UPDATE_USE_LATEST:-0}" != 0 ]]; then
		global_use_latest=1
	fi
	for arg in "$@"; do
		case "$arg" in
		--all) all=1 ;;
		--use-latest) force_use_latest=1 ;;
		--replace) update_replace=1 ;;
		--asdf)
			update_asdf=1
			selected=1
			;;
		--plugin)
			update_plugins=1
			selected=1
			;;
		--version)
			update_versions=1
			selected=1
			;;
		-u | --home)
			scope="$(extras_select_scope "$scope" --home)"
			explicit_scope=1
			;;
		-p | --parent)
			scope="$(extras_select_scope "$scope" --parent)"
			explicit_scope=1
			;;
		--local)
			scope="$(extras_select_scope "$scope" --local)"
			explicit_scope=1
			;;
		-*) extras_fail "unknown update option: $arg" ;;
		*) positional+=("$arg") ;;
		esac
	done
	set -- ${positional[@]+"${positional[@]}"}
	if ((all && selected)); then
		extras_fail "--all cannot be combined with --asdf, --plugin or --version"
	fi
	[[ "${1:-}" != all ]] || extras_fail "use --all instead of the all positional argument"
	if ((all)); then
		[[ $# -eq 0 ]] || extras_fail "--all does not accept a plugin or version"
	fi
	if ((selected == 0)); then
		update_plugins=1
		update_versions=1
		if [[ $# -eq 0 ]] && ((explicit_scope == 0)); then
			update_asdf=1
		fi
	fi
	if ((all)); then
		update_asdf=1
	fi
	if ((update_versions == 0)) && [[ $# -gt 1 ]]; then
		extras_fail "a target version requires --version"
	fi
	if ((update_plugins == 0 && update_versions == 0)) && [[ $# -gt 0 ]]; then
		extras_fail "a plugin requires --plugin or --version"
	fi

	resolve_default_version() {
		local plugin_name="$1"
		plugin_env_suffix="$(extras_plugin_env_suffix "$plugin_name")"
		plugin_version_var="ASDF_EXTRAS_UPDATE_DEFAULT_VERSION_${plugin_env_suffix}"
		if [[ "${!plugin_version_var+x}" == x ]]; then
			implicit_version="${!plugin_version_var}"
		elif [[ "${ASDF_EXTRAS_UPDATE_DEFAULT_VERSION+x}" == x ]]; then
			implicit_version="$ASDF_EXTRAS_UPDATE_DEFAULT_VERSION"
		else
			implicit_version=latest
		fi
		printf '%s\n' "$implicit_version"
	}

	resolve_default_latest_prefix() {
		local plugin_name="$1"
		plugin_env_suffix="$(extras_plugin_env_suffix "$plugin_name")"
		plugin_prefix_var="ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX_${plugin_env_suffix}"
		if [[ "${!plugin_prefix_var+x}" == x ]]; then
			implicit_prefix="${!plugin_prefix_var}"
		elif [[ "${ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX+x}" == x ]]; then
			implicit_prefix="$ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX"
		else
			implicit_prefix=""
		fi
		printf '%s\n' "$implicit_prefix"
	}

	resolve_use_latest_mode() {
		local plugin_name="$1"
		if ((force_use_latest)); then
			printf '1\n'
			return 0
		fi
		plugin_env_suffix="$(extras_plugin_env_suffix "$plugin_name")"
		plugin_use_latest_var="ASDF_EXTRAS_UPDATE_USE_LATEST_${plugin_env_suffix}"
		if [[ "${!plugin_use_latest_var+x}" == x ]]; then
			if [[ "${!plugin_use_latest_var}" != 0 ]]; then
				printf '1\n'
			else
				printf '0\n'
			fi
			return 0
		fi
		if ((global_use_latest)); then
			printf '1\n'
		else
			printf '0\n'
		fi
	}

	# Prints the install arguments for one plugin, one per line. Explicit versions
	# or the configured default may be lists, which are read as data (no
	# expansion). system is a literal entry and is never turned into a request.
	resolve_install_targets() {
		local plugin_name="$1"
		shift
		use_latest_for_plugin="$(resolve_use_latest_mode "$plugin_name")"
		elements=()
		if [[ $# -gt 0 ]]; then
			elements=("$@")
		elif [[ "$use_latest_for_plugin" == 1 ]]; then
			read -r -a elements <<<"$(resolve_default_latest_prefix "$plugin_name")"
		else
			read -r -a elements <<<"$(resolve_default_version "$plugin_name")"
		fi
		[[ ${#elements[@]} -gt 0 ]] || elements=(latest)
		for element in "${elements[@]}"; do
			if [[ "$element" == system || "$element" == latest || "$element" == latest:* ]]; then
				printf '%s\n' "$element"
			elif [[ "$use_latest_for_plugin" == 1 ]]; then
				printf 'latest:%s\n' "$element"
			else
				printf '%s\n' "$element"
			fi
		done
	}

	read_targets() {
		targets=()
		while IFS= read -r candidate_version; do
			targets+=("$candidate_version")
		done < <(resolve_install_targets "$@")
	}

	scope="${scope:---home}"
	# Resolve relevant scope inputs before performing any updates.
	file=""
	plugins=""
	if ((update_versions || update_plugins)); then
		if ((update_versions)); then
			file="$(extras_scope_file "$scope")"
		fi
		if [[ $# -eq 0 ]] && ((explicit_scope && update_versions)); then
			[[ -f "$file" ]] || extras_fail "scope file does not exist: $file"
			plugins="$(awk 'NF && $1 !~ /^#/ {print $1}' "$file")"
		elif [[ $# -eq 0 ]]; then
			plugins="$(command asdf plugin list)"
		fi
		if [[ $# -eq 0 && "$scope" == --home ]] && ((update_versions)); then
			# Self-update cleanup can remove scripts needed by later installs.
			plugins="$(printf '%s\n' "$plugins" | awk -v extras="$extras_plugin" '
				$0 == extras { self = $0; next }
				{ print }
				END { if (self != "") print self }
			')"
		fi
	fi
	if ((update_asdf)); then
		if ! "$BASH" "${extras_lib}/update-asdf.bash"; then
			printf "asdf-extras: asdf itself could not be updated; continuing remaining updates\n" >&2
			failed=1
		fi
	fi
	if ((update_plugins == 0 && update_versions == 0)); then
		return "$failed"
	fi
	if [[ $# -eq 0 ]]; then
		while IFS= read -r plugin; do
			[[ -n "$plugin" ]] || continue
			read_targets "$plugin"
			if ! update_one "$plugin" "$scope" "$file" "${targets[@]}"; then
				printf "asdf-extras: skipped %s (update failed; see error above)\n" "$plugin" >&2
				failed=1
			fi
		done <<<"$plugins"
	else
		read_targets "$1" "${@:2}"
		if ! update_one "$1" "$scope" "$file" "${targets[@]}"; then
			failed=1
		fi
	fi
	return "$failed"
}

main "$@"

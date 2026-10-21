#!/usr/bin/env bash

set -euo pipefail

main() {
	local standalone=0
	if [[ "${1:-}" == --standalone ]]; then
		standalone=1
		shift
	fi
	local delegated=0
	if [[ "${1:-}" == --delegated ]]; then
		delegated=1
		shift
	fi
	local subcommand="${1:-}" current="${!#}" arg plugin="" position=0
	local scope="" targets="" all=0 options="" candidates="" candidate
	if ((standalone)); then
		if [[ $# -le 1 ]]; then
			for candidate in completion help init install prune update version --help --version; do
				[[ "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
			done
			return 0
		fi
		case "$subcommand" in
		help | --help | -h)
			[[ $# -eq 2 ]] || return 0
			for candidate in install update prune completion; do
				[[ "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
			done
			return 0
			;;
		completion)
			local completion_asdf=0 completion_shell=""
			shift
			while [[ $# -gt 1 ]]; do
				if [[ "$1" == --asdf ]]; then
					completion_asdf=1
				else
					completion_shell="$1"
				fi
				shift
			done
			if ((completion_asdf == 0)) && [[ --asdf == "$current"* ]]; then
				printf '%s\n' --asdf
			fi
			if [[ -z "$completion_shell" ]]; then
				for candidate in bash zsh fish elvish nushell; do
					[[ "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
				done
			fi
			return 0
			;;
		init)
			[[ $# -eq 2 ]] || return 0
			for candidate in bash zsh fish elvish nushell; do
				[[ "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
			done
			return 0
			;;
		esac
	fi
	[[ $# -gt 1 ]] || {
		printf 'update\n'
		return 0
	}
	shift
	[[ "$subcommand" == install || "$subcommand" == update || "$subcommand" == prune ]] || return 0
	while [[ $# -gt 1 ]]; do
		arg="$1"
		shift
		case "$arg" in
		-u | --home | -p | --parent | --local) scope="$arg" ;;
		--all) all=1 ;;
		--asdf | --plugin | --version) targets="$targets $arg" ;;
		-*) ;;
		*)
			position=$((position + 1))
			[[ $position -ne 1 ]] || plugin="$arg"
			;;
		esac
	done
	if [[ -z "$scope" ]]; then
		options="-u --home -p --parent --local"
	fi
	if [[ "$subcommand" == prune ]]; then
		((position == 0)) || return 0
		candidates="$(command asdf plugin list)" || {
			printf 'asdf-extras: could not list plugins for completion\n' >&2
			return 1
		}
		while IFS= read -r candidate; do
			[[ -z "$candidate" || "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
		done <<<"$candidates"
		return 0
	fi
	if [[ "$subcommand" == update ]] && ((all == 0)); then
		[[ -n "$targets" || $position -gt 0 ]] || options="$options --all"
		for arg in --asdf --plugin --version; do
			[[ " $targets " == *" $arg "* ]] || options="$options $arg"
		done
	fi
	if [[ "$current" == -* || -z "$current" ]]; then
		for candidate in $options; do
			[[ "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
		done
	fi
	[[ "$current" != -* ]] || return 0
	((all == 0)) || return 0
	if [[ "$subcommand" == update && -n "$targets" && "$targets" != *--plugin* && "$targets" != *--version* ]]; then
		return 0
	fi
	if ((delegated)); then
		if ((position == 1)) && [[ latest == "$current"* ]]; then
			printf 'latest\n'
		fi
		return 0
	fi
	case "$position" in
	0)
		candidates="$(command asdf plugin list)" || {
			printf 'asdf-extras: could not list plugins for completion\n' >&2
			return 1
		}
		;;
	1)
		if [[ "$subcommand" == update && -n "$targets" && "$targets" != *--version* ]]; then
			return 0
		fi
		candidates="$(command asdf list all "$plugin")" || {
			printf 'asdf-extras: could not list versions for completion: %s\n' "$plugin" >&2
			return 1
		}
		candidates="$(printf 'latest\n%s\n' "$candidates")"
		;;
	*) return 0 ;;
	esac
	while IFS= read -r candidate; do
		[[ -z "$candidate" || "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
	done <<<"$candidates"
}

main "$@"

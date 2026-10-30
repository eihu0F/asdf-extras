#!/usr/bin/env bash

# Candidates for asdf shell, whose words are <plugin> <version>... or
# --unset <plugin>. The last argument is the word being completed.
extras_shell_candidates() {
	local current="${!#}" candidate candidates
	if [[ "${1:-}" == --unset ]] && (($# > 1)); then
		# Only the plugin follows --unset.
		(($# == 2)) || return 0
	elif (($# == 1)); then
		[[ --unset != "$current"* ]] || printf '%s\n' --unset
	else
		# Only installed versions are useful to select, so list those.
		candidates="$(
			extras_installed_versions "$1"
			printf 'system\n'
		)"
		while IFS= read -r candidate; do
			[[ -z "$candidate" || "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
		done <<<"$candidates"
		return 0
	fi
	[[ "$current" != -* ]] || return 0
	candidates="$(command asdf plugin list)" || {
		printf 'asdf-extras: could not list plugins for completion\n' >&2
		return 1
	}
	while IFS= read -r candidate; do
		[[ -z "$candidate" || "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
	done <<<"$candidates"
}

# Answers a completion stub (see `invoke --complete`). Usage:
#   extras_completion_query [--standalone] <cword> <word>...
# <word>... are all the words of the command line, the command name first, and
# <cword> is the index of the word being completed. The first output line tells the
# stub what to do with native asdf completion, which only the stub can run:
#   native none             do not run it
#   native original        run it with the words as typed
#   native drop <i>...      run it without the words at these indexes
# The following lines are candidates, one per line.
extras_completion_query() {
	local standalone=0
	if [[ "${1:-}" == --standalone ]]; then
		standalone=1
		shift
	fi
	local cword="$1" i
	# Drop <cword> and the command name, so that $1 is the first argument and
	# ${!i} is the word with index i.
	shift 2
	local -a upto=() drop=()
	for ((i = 1; i <= cword && i <= $#; i++)); do
		upto+=("${!i}")
	done
	if ((standalone)); then
		printf 'native none\n'
		extras_completion_candidates --standalone "${upto[@]}"
		return 0
	fi
	if ((cword < 2)); then
		printf 'native original\n'
		# Completing the subcommand itself.
		if ((cword == 1)); then
			extras_completion_candidates "${upto[@]}"
		fi
		return 0
	fi
	case "${upto[0]}" in
	install)
		# Scope flags and --replace belong to extras: native completes without them,
		# including the ones typed after the cursor.
		for ((i = 2; i <= $#; i++)); do
			if ((i != cword)); then
				case "${!i}" in
				-u | --home | -p | --parent | --local | --replace) drop+=("$i") ;;
				esac
			fi
		done
		if ((${#drop[@]})); then
			printf 'native drop %s\n' "${drop[*]}"
		else
			printf 'native original\n'
		fi
		extras_completion_candidates --delegated "${upto[@]}"
		;;
	update | get | shell)
		printf 'native none\n'
		extras_completion_candidates "${upto[@]}"
		;;
	*) printf 'native original\n' ;;
	esac
}

# Prints completion candidates for the words typed so far; the shell completion
# scripts query it through `completion --candidates`.
extras_completion_candidates() {
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
	local scope="" targets="" all=0 replace=0 options="" candidates="" candidate
	if ((standalone)); then
		if [[ $# -le 1 ]]; then
			for candidate in completion get help init install prune update version --help --version; do
				[[ "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
			done
			return 0
		fi
		case "$subcommand" in
		help | --help | -h)
			[[ $# -eq 2 ]] || return 0
			for candidate in install update get shell prune completion; do
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
		for candidate in update get shell; do
			[[ "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
		done
		return 0
	}
	shift
	if [[ "$subcommand" == shell ]]; then
		extras_shell_candidates "$@"
		return
	fi
	[[ "$subcommand" == install || "$subcommand" == update || "$subcommand" == get || "$subcommand" == prune ]] || return 0
	while [[ $# -gt 1 ]]; do
		arg="$1"
		shift
		case "$arg" in
		-u | --home | -p | --parent | --local) scope="$arg" ;;
		--all) all=1 ;;
		--use-latest) ;;
		--replace) replace=1 ;;
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
	if [[ "$replace" == 0 && ("$subcommand" == install || "$subcommand" == update) ]] && ((all == 0)); then
		options="$options --replace"
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
		if [[ " ${*} " != *" --use-latest "* ]]; then
			options="$options --use-latest"
		fi
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
		if ((position >= 1)); then
			for candidate in latest system; do
				[[ "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
			done
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
	*)
		if [[ "$subcommand" == get ]] ||
			[[ "$subcommand" == update && -n "$targets" && "$targets" != *--version* ]]; then
			return 0
		fi
		candidates="$(command asdf list all "$plugin")" || {
			printf 'asdf-extras: could not list versions for completion: %s\n' "$plugin" >&2
			return 1
		}
		candidates="$(printf 'latest\nsystem\n%s\n' "$candidates")"
		;;
	esac
	while IFS= read -r candidate; do
		[[ -z "$candidate" || "$candidate" != "$current"* ]] || printf '%s\n' "$candidate"
	done <<<"$candidates"
}

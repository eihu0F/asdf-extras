_asdf_extras_dispatch() {
	local dispatcher

	dispatcher="${ASDF_EXTRAS_DISPATCHER:-}"
	if [[ -z "$dispatcher" ]]; then
		printf "asdf-extras: dispatcher not set: ASDF_EXTRAS_DISPATCHER\n" >&2
		return 1
	fi

	if [[ ! -r "$dispatcher" ]]; then
		printf "asdf-extras: dispatcher not found: %s\n" "$dispatcher" >&2
		return 1
	fi

	command bash "$dispatcher" "$@"
}

_asdf_extras_refresh() {
	local previous="$1" update_rc="$2" executable init_code
	if ! executable="$(command asdf which asdf-extras)"; then
		printf 'asdf-extras: cannot resolve updated executable; retry eval "$(asdf-extras init zsh)" after fixing version selection\n' >&2
		return 1
	fi
	[[ "$executable" != "$previous" ]] || return "$update_rc"
	if ! init_code="$("$executable" init zsh)" || [[ -z "$init_code" ]]; then
		printf 'asdf-extras: cannot generate initialization; retry eval "$(asdf-extras init zsh)"\n' >&2
		return 1
	fi
	if ! eval "$init_code"; then
		printf 'asdf-extras: initialization failed; retry eval "$(asdf-extras init zsh)"\n' >&2
		return 1
	fi
	return "$update_rc"
}

asdf() {
	local arg previous update_rc

	if [[ "${1:-}" == "completion" ]]; then
		shift
		case "${1:-}" in
		bash | zsh | fish | nushell | elvish) _asdf_extras_dispatch completion --asdf "$@" ;;
		*) _asdf_extras_dispatch completion "$@" ;;
		esac
		return $?
	fi

	if [[ "${1:-}" == "update" ]]; then
		shift
		if ! previous="$(command asdf which asdf-extras)"; then
			printf 'asdf-extras: cannot resolve current executable before update\n' >&2
			return 1
		fi
		if _asdf_extras_dispatch update "$@"; then
			update_rc=0
		else
			update_rc=$?
		fi
		_asdf_extras_refresh "$previous" "$update_rc"
		return $?
	fi

	if [[ "${1:-}" == "install" ]]; then
		shift
		for arg in "$@"; do
			if [[ "$arg" == "-u" || "$arg" == "--home" || "$arg" == "-p" || "$arg" == "--parent" || "$arg" == "--local" ]]; then
				_asdf_extras_dispatch install "$@"
				return $?
			fi
		done
		command asdf install "$@"
		return $?
	fi

	command asdf "$@"
}

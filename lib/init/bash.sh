_asdf_extras_dispatch() {
	local init_dir lib_dir dispatcher

	init_dir=$(dirname "${BASH_SOURCE[0]}")
	lib_dir=$(dirname "$init_dir")
	dispatcher="${lib_dir}/commands/dispatch.bash"

	if [[ ! -r "$dispatcher" ]]; then
		printf "asdf-extras: dispatcher not found: %s\n" "$dispatcher" >&2
		return 1
	fi

	command bash "$dispatcher" "$@"
}

_asdf_extras_refresh() {
	local previous="$1" update_rc="$2" executable init_code completion_code
	local -a completion_args=()
	if ! executable="$(command asdf which asdf-extras)"; then
		printf 'asdf-extras: cannot resolve updated executable; retry eval "$(asdf-extras init bash)" after fixing version selection\n' >&2
		return 1
	fi
	[[ "$executable" != "$previous" ]] || return "$update_rc"
	# init does not load completion, so reload it only where it was enabled,
	# in the same mode (the asdf overlay registers _ASDF_EXTRAS_NATIVE_COMPLETE).
	if [[ -n "${ASDF_EXTRAS_COMPLETION_HELPER:-}" ]]; then
		completion_args=(completion)
		[[ -z "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]] || completion_args+=(--asdf)
		completion_args+=(bash)
	fi
	if ! init_code="$("$executable" init bash)" || [[ -z "$init_code" ]]; then
		printf 'asdf-extras: cannot generate initialization; retry eval "$(asdf-extras init bash)"\n' >&2
		return 1
	fi
	if ! eval "$init_code"; then
		printf 'asdf-extras: initialization failed; retry eval "$(asdf-extras init bash)"\n' >&2
		return 1
	fi
	if ((${#completion_args[@]})); then
		if ! completion_code="$("$executable" "${completion_args[@]}")" || [[ -z "$completion_code" ]]; then
			printf 'asdf-extras: cannot generate completion; retry eval "$(asdf-extras %s)"\n' "${completion_args[*]}" >&2
			return 1
		fi
		if ! eval "$completion_code"; then
			printf 'asdf-extras: completion reload failed; retry eval "$(asdf-extras %s)"\n' "${completion_args[*]}" >&2
			return 1
		fi
	fi
	return "$update_rc"
}

asdf() {
	local arg previous update_rc

	case "${1:-}" in
	install | update | completion)
		for arg in "$@"; do
			if [[ "$arg" == --help || "$arg" == -h ]]; then
				_asdf_extras_dispatch help --asdf "$@"
				return $?
			fi
		done
		;;
	esac

	case "${1:-}" in
	help | --help | -h)
		_asdf_extras_dispatch help --asdf "$@"
		return $?
		;;
	esac

	if [[ "${1:-}" == "completion" ]]; then
		shift
		case "${1:-}" in
		bash | zsh | fish | nushell | elvish) _asdf_extras_dispatch completion --asdf --wrappers "$@" ;;
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

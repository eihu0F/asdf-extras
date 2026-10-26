_asdf_extras_dispatch() {
	local subcommand="$1"
	shift

	# Reach extras through the entry point this init came from, so a removed
	# runtime does not leave a stale path behind.
	case "${ASDF_EXTRAS_INIT_ORIGIN:-}" in
	plugin) command asdf cmd "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" "$subcommand" -- "$@" ;;
	installed) command asdf exec asdf-extras "$subcommand" "$@" ;;
	*)
		printf "asdf-extras: entry point not set: ASDF_EXTRAS_INIT_ORIGIN\n" >&2
		return 1
		;;
	esac
}

_asdf_extras_refresh() {
	local previous="$1" update_rc="$2" executable init_code completion_code
	local -a completion_args=()
	if ! executable="$(command asdf which asdf-extras)"; then
		printf 'asdf-extras: cannot resolve updated executable; retry eval "$(asdf-extras init zsh)" after fixing version selection\n' >&2
		return 1
	fi
	[[ "$executable" != "$previous" ]] || return "$update_rc"
	# init does not load completion, so reload it only where it was enabled,
	# in the same mode (the asdf overlay registers _ASDF_EXTRAS_NATIVE_COMPLETE).
	if [[ -n "${ASDF_EXTRAS_COMPLETION_ORIGIN:-}" ]]; then
		completion_args=(completion)
		[[ -z "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]] || completion_args+=(--asdf)
		completion_args+=(zsh)
	fi
	if ! init_code="$("$executable" init zsh)" || [[ -z "$init_code" ]]; then
		printf 'asdf-extras: cannot generate initialization; retry eval "$(asdf-extras init zsh)"\n' >&2
		return 1
	fi
	if ! eval "$init_code"; then
		printf 'asdf-extras: initialization failed; retry eval "$(asdf-extras init zsh)"\n' >&2
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

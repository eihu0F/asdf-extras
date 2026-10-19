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

asdf() {
	local arg

	if [[ "${1:-}" == "completion" ]]; then
		shift
		_asdf_extras_dispatch completion "$@"
		return $?
	fi

	if [[ "${1:-}" == "update" ]]; then
		shift
		_asdf_extras_dispatch update "$@"
		return $?
	fi

	if [[ "${1:-}" == "install" ]]; then
		shift
		for arg in "$@"; do
			if [[ "$arg" == "-u" || "$arg" == "--home" || "$arg" == "-p" || "$arg" == "--parent" ]]; then
				_asdf_extras_dispatch install "$@"
				return $?
			fi
		done
		command asdf install "$@"
		return $?
	fi

	command asdf "$@"
}

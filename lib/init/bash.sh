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

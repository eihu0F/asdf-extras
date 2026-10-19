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

	if [[ "${1:-}" == "install" && "${2:-}" == "-u" ]]; then
		shift 2
		_asdf_extras_dispatch install "$@"
		return $?
	fi

	command asdf "$@"
}

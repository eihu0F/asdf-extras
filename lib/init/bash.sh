_asdf_extras_dispatch() {
	if command -v asdf-extras >/dev/null 2>&1; then
		asdf-extras "$@"
		return $?
	fi
	command asdf cmd extras "$@"
}

asdf() {
	if [[ "${1:-}" == "completion" && "${2:-}" == "bash" ]]; then
		command asdf completion bash
		printf "\n# asdf-extras init overlay\n"
		_asdf_extras_dispatch init bash
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

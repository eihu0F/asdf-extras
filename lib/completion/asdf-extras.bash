# Asks extras for candidates through the entry point recorded at load time.
_asdf_extras_query() {
	case "${ASDF_EXTRAS_COMPLETION_ORIGIN:-}" in
	plugin) command asdf cmd "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" __complete -- "$@" ;;
	installed) command asdf exec asdf-extras __complete "$@" ;;
	*) return 1 ;;
	esac
}

_asdf_extras_standalone_complete() {
	local output candidate
	COMPREPLY=()
	output="$(_asdf_extras_query --standalone "${COMP_WORDS[@]:1:COMP_CWORD}")" || return 1
	while IFS= read -r candidate; do
		[[ -z "$candidate" ]] || COMPREPLY+=("$candidate")
	done <<<"$output"
}

complete -o bashdefault -o default -F _asdf_extras_standalone_complete asdf-extras

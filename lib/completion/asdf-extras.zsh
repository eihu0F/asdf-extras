# Asks extras for candidates through the entry point recorded at load time.
_asdf_extras_query() {
	case "${ASDF_EXTRAS_COMPLETION_ORIGIN:-}" in
	plugin) command asdf cmd "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" completion -- --candidates "$@" ;;
	installed) command asdf exec asdf-extras completion --candidates "$@" ;;
	*) return 1 ;;
	esac
}

_asdf_extras_standalone_complete() {
	local output candidate
	local -a candidates
	output="$(_asdf_extras_query --standalone "${words[@]:1:$((CURRENT - 1))}")" || return 1
	while IFS= read -r candidate; do
		[[ -z "$candidate" ]] || candidates+=("$candidate")
	done <<<"$output"
	((${#candidates})) || return 1
	compadd -- "${candidates[@]}"
}

if ! whence -w compdef >/dev/null; then
	autoload -Uz compinit
	compinit -i -D || return
fi
compdef _asdf_extras_standalone_complete asdf-extras

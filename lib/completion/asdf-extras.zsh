# Asks the runtime for completion (asdf-extras invoke --complete) through the
# entry point recorded at load time. Returns 2 when no runtime can be resolved, so
# that a caller can keep native completion working.
_asdf_extras_query() {
	local exe
	case "${ASDF_EXTRAS_COMPLETION_ORIGIN:-}" in
	plugin) command asdf cmd "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" invoke -- --complete --shell zsh --protocol 1 "$@" ;;
	installed)
		exe="$(command asdf which asdf-extras 2>/dev/null)" || return 2
		"$exe" invoke --complete --shell zsh --protocol 1 "$@"
		;;
	*) return 2 ;;
	esac
}

_asdf_extras_standalone_complete() {
	local output candidate rc=0
	local -a candidates
	output="$(_asdf_extras_query --standalone --cword "$((CURRENT - 1))" -- "${words[@]}")" || rc=$?
	((rc == 0)) || return $((rc == 2 ? 1 : 1))
	# The first line only matters to the asdf overlay.
	while IFS= read -r candidate; do
		[[ -z "$candidate" ]] || candidates+=("$candidate")
	done <<<"${output#*$'\n'}"
	((${#candidates})) || return 1
	compadd -- "${candidates[@]}"
}

if ! whence -w compdef >/dev/null; then
	autoload -Uz compinit
	compinit -i -D || return
fi
compdef _asdf_extras_standalone_complete asdf-extras

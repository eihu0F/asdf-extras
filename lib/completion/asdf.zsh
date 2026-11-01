# Fixed glue: the runtime decides what to complete and how native completion is used
# (see extras_completion_query); this only runs native completion, which is shell
# code, and adds the candidates. The runtime counts words from 0; Zsh from 1.
_asdf_extras_complete() {
	local output directive extras candidate rc=1 query_rc=0 i dropped
	local -a candidates drop normalized
	output="$(_asdf_extras_query --cword "$((CURRENT - 1))" -- "${words[@]}")" || query_rc=$?
	if ((query_rc == 2)); then
		# No runtime: native completion alone.
		output="native original"
	elif ((query_rc != 0)); then
		return 1
	fi
	directive="${output%%$'\n'*}"
	extras="${output#"$directive"}"
	while IFS= read -r candidate; do
		[[ -z "$candidate" ]] || candidates+=("$candidate")
	done <<<"$extras"
	case "$directive" in
	"native none") ;;
	"native drop "*)
		local normalized_current="$CURRENT"
		read -r -A drop <<<"${directive#native drop }"
		for ((i = 1; i <= ${#words}; i++)); do
			dropped=0
			for candidate in "${drop[@]}"; do
				((candidate + 1 != i)) || dropped=1
			done
			if ((dropped)); then
				((i >= CURRENT)) || normalized_current=$((normalized_current - 1))
				continue
			fi
			normalized+=("${words[i]}")
		done
		local -a words=("${normalized[@]}")
		local CURRENT="$normalized_current"
		rc=0
		"$_ASDF_EXTRAS_NATIVE_COMPLETE" "$@" || rc=$?
		;;
	*)
		rc=0
		"$_ASDF_EXTRAS_NATIVE_COMPLETE" "$@" || rc=$?
		;;
	esac
	if ((${#candidates})); then
		compadd -- "${candidates[@]}" && rc=0
	fi
	return "$rc"
}

_asdf_extras_register_completion() {
	if ! whence -w compdef >/dev/null; then
		autoload -Uz compinit
		compinit -i -D || return
	fi
	local native="${_comps[asdf]:-}" code
	[[ "$native" != _asdf_extras_complete ]] || return 0
	if [[ -z "$native" ]]; then
		if ! code="$(command asdf completion zsh)" || [[ -z "$code" ]]; then
			print -u2 'asdf-extras: could not load native Zsh completion'
			return 1
		fi
		eval "_asdf_extras_native_complete() {
$code
}" || return
		native=_asdf_extras_native_complete
	fi
	_ASDF_EXTRAS_NATIVE_COMPLETE="$native"
	compdef _asdf_extras_complete asdf
}

_asdf_extras_register_completion

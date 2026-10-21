_asdf_extras_complete() {
	local cmd="${words[2]:-}" output candidate rc=1
	local -a candidates normalized
	local i scoped=0
	if ((CURRENT > 2)) && [[ "$cmd" == install || "$cmd" == update ]]; then
		if [[ "$cmd" == install ]]; then
			output="$(command bash "$ASDF_EXTRAS_COMPLETION_HELPER" --delegated "${words[@]:1:$((CURRENT - 1))}")" || return 1
		else
			output="$(command bash "$ASDF_EXTRAS_COMPLETION_HELPER" "${words[@]:1:$((CURRENT - 1))}")" || return 1
		fi
		while IFS= read -r candidate; do
			[[ -z "$candidate" ]] || candidates+=("$candidate")
		done <<<"$output"
		if [[ "$cmd" == install ]]; then
			normalized=("${words[1]}" install)
			for ((i = 3; i < CURRENT; i++)); do
				case "${words[i]}" in
				-u | --home | -p | --parent | --local) scoped=1 ;;
				*) normalized+=("${words[i]}") ;;
				esac
			done
			normalized+=("${words[CURRENT]}")
			if ((scoped)); then
				local -a words=("${normalized[@]}")
				local CURRENT=${#normalized}
			fi
			rc=0
			"$_ASDF_EXTRAS_NATIVE_COMPLETE" "$@" || rc=$?
		fi
	else
		rc=0
		"$_ASDF_EXTRAS_NATIVE_COMPLETE" "$@" || rc=$?
		if ((CURRENT == 2)); then
			candidates=(update)
		fi
	fi
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

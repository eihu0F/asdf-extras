_asdf_extras_complete() {
	local cmd="${words[2]:-}" output candidate rc=1
	local -a candidates normalized
	local i scoped=0 normalized_current="$CURRENT"
	if ((CURRENT > 2)) && [[ "$cmd" == install || "$cmd" == update || "$cmd" == get ]]; then
		if [[ "$cmd" == install ]]; then
			output="$(_asdf_extras_query --delegated "${words[@]:1:$((CURRENT - 1))}")" || return 1
		else
			output="$(_asdf_extras_query "${words[@]:1:$((CURRENT - 1))}")" || return 1
		fi
		while IFS= read -r candidate; do
			[[ -z "$candidate" ]] || candidates+=("$candidate")
		done <<<"$output"
		if [[ "$cmd" == install ]]; then
			normalized=("${words[1]}" install)
			for ((i = 3; i <= ${#words}; i++)); do
				case "${words[i]}" in
				-u | --home | -p | --parent | --local)
					if ((i != CURRENT)); then
						scoped=1
						((i >= CURRENT)) || normalized_current=$((normalized_current - 1))
						continue
					fi
					normalized+=("${words[i]}")
					;;
				*) normalized+=("${words[i]}") ;;
				esac
			done
			if ((scoped)); then
				local -a words=("${normalized[@]}")
				local CURRENT="$normalized_current"
			fi
			rc=0
			"$_ASDF_EXTRAS_NATIVE_COMPLETE" "$@" || rc=$?
		fi
	else
		rc=0
		"$_ASDF_EXTRAS_NATIVE_COMPLETE" "$@" || rc=$?
		if ((CURRENT == 2)); then
			candidates=(update get)
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

_asdf_extras_complete() {
	local cur="${COMP_WORDS[COMP_CWORD]}" cmd="${COMP_WORDS[1]:-}"
	local candidate output rc=0 i scoped=0 normalized_cword="$COMP_CWORD"
	local -a normalized=() mode=()
	local original_cword="$COMP_CWORD"
	COMPREPLY=()
	if [[ "$cmd" == install || "$cmd" == update || "$cmd" == get ]] && ((COMP_CWORD > 1)); then
		[[ "$cmd" != install ]] || mode=(--delegated)
		if ! output="$(_asdf_extras_query ${mode[@]+"${mode[@]}"} "${COMP_WORDS[@]:1:COMP_CWORD}")"; then
			return 1
		fi
		# Strip extras flags only in a local completion context; leave the input untouched.
		normalized=("${COMP_WORDS[0]}" install)
		for ((i = 2; i < ${#COMP_WORDS[@]}; i++)); do
			case "${COMP_WORDS[i]}" in
			-u | --home | -p | --parent | --local)
				if ((i != original_cword)); then
					scoped=1
					((i >= original_cword)) || normalized_cword=$((normalized_cword - 1))
					continue
				fi
				normalized+=("${COMP_WORDS[i]}")
				;;
			*) normalized+=("${COMP_WORDS[i]}") ;;
			esac
		done
		if [[ "$cmd" == install && -n "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]]; then
			if ((scoped)); then
				local -a COMP_WORDS=("${normalized[@]}")
				local COMP_CWORD="$normalized_cword"
				local COMP_LINE COMP_POINT
				printf -v COMP_LINE '%q ' "${normalized[@]}"
				COMP_LINE="${COMP_LINE% }"
				local prefix
				printf -v prefix '%q ' "${normalized[@]:0:COMP_CWORD+1}"
				COMP_POINT=$((${#prefix} - 1))
				"$_ASDF_EXTRAS_NATIVE_COMPLETE" "${normalized[0]}" "$cur" "${normalized[COMP_CWORD - 1]}" || rc=$?
			else
				"$_ASDF_EXTRAS_NATIVE_COMPLETE" "$@" || rc=$?
			fi
		fi
	else
		if [[ -n "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]]; then
			"$_ASDF_EXTRAS_NATIVE_COMPLETE" "$@" || rc=$?
		fi
		output=""
		if ((original_cword == 1)); then
			for candidate in update get; do
				[[ "$candidate" != "$cur"* ]] || output+="$candidate"$'\n'
			done
		fi
	fi
	while IFS= read -r candidate; do
		[[ -n "$candidate" ]] || continue
		if [[ " ${COMPREPLY[*]-} " != *" $candidate "* ]]; then
			COMPREPLY+=("$candidate")
		fi
	done <<<"$output"
	# Localized COMP_WORDS/COMP_CWORD disappear when this function returns.
	return "$rc"
}

_asdf_extras_register_completion() {
	local registration native="" i
	local -a spec=()
	if ! registration="$(complete -p asdf 2>/dev/null)"; then
		if ! registration="$(command asdf completion bash)"; then
			printf 'asdf-extras: could not load native Bash completion\n' >&2
			return 1
		fi
		if ! eval "$registration"; then
			printf 'asdf-extras: could not evaluate native Bash completion\n' >&2
			return 1
		fi
		if ! registration="$(complete -p asdf 2>/dev/null)"; then
			printf 'asdf-extras: native Bash completion did not register asdf\n' >&2
			return 1
		fi
	fi
	# complete -p emits shell-quoted arguments. Decode that trusted builtin output.
	eval "spec=(${registration#complete })"
	for ((i = 0; i < ${#spec[@]}; i++)); do
		if [[ "${spec[i]}" == -F ]]; then
			native="${spec[i + 1]}"
			[[ "$native" != _asdf_extras_complete ]] || return 0
			spec[i + 1]=_asdf_extras_complete
			break
		fi
	done
	if [[ -z "$native" ]] || ! declare -F "$native" >/dev/null; then
		printf 'asdf-extras: native Bash completion is not a function; registration left unchanged\n' >&2
		return 1
	fi
	_ASDF_EXTRAS_NATIVE_COMPLETE="$native"
	complete "${spec[@]}"
}

_asdf_extras_register_completion

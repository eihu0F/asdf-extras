# Fixed glue: the runtime decides what to complete and how native completion is used
# (see extras_completion_query); this only runs native completion, which is shell
# code, and merges the candidates.
_asdf_extras_complete() {
	local cur="${COMP_WORDS[COMP_CWORD]}" candidate output directive extras rc=0 query_rc=0 i dropped
	local original_cword="$COMP_CWORD"
	local -a drop=() normalized=()
	COMPREPLY=()
	output="$(_asdf_extras_query --cword "$COMP_CWORD" -- "${COMP_WORDS[@]}")" || query_rc=$?
	if ((query_rc == 2)); then
		# No runtime: native completion alone.
		output="native original"
	elif ((query_rc != 0)); then
		return 1
	fi
	directive="${output%%$'\n'*}"
	extras="${output#"$directive"}"
	if [[ -n "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]]; then
		case "$directive" in
		"native none") ;;
		"native drop "*)
			read -r -a drop <<<"${directive#native drop }"
			local normalized_cword="$COMP_CWORD"
			for ((i = 0; i < ${#COMP_WORDS[@]}; i++)); do
				dropped=0
				for candidate in "${drop[@]}"; do
					((candidate != i)) || dropped=1
				done
				if ((dropped)); then
					((i >= original_cword)) || normalized_cword=$((normalized_cword - 1))
					continue
				fi
				normalized+=("${COMP_WORDS[i]}")
			done
			local -a COMP_WORDS=("${normalized[@]}")
			local COMP_CWORD="$normalized_cword"
			local COMP_LINE COMP_POINT
			printf -v COMP_LINE '%q ' "${normalized[@]}"
			COMP_LINE="${COMP_LINE% }"
			local prefix
			printf -v prefix '%q ' "${normalized[@]:0:COMP_CWORD+1}"
			COMP_POINT=$((${#prefix} - 1))
			"$_ASDF_EXTRAS_NATIVE_COMPLETE" "${normalized[0]}" "$cur" "${normalized[COMP_CWORD - 1]}" || rc=$?
			;;
		*) "$_ASDF_EXTRAS_NATIVE_COMPLETE" "$@" || rc=$? ;;
		esac
	fi
	while IFS= read -r candidate; do
		[[ -n "$candidate" ]] || continue
		if [[ " ${COMPREPLY[*]-} " != *" $candidate "* ]]; then
			COMPREPLY+=("$candidate")
		fi
	done <<<"$extras"
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

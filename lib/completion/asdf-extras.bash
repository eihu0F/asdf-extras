_asdf_extras_standalone_complete() {
	local output candidate
	COMPREPLY=()
	output="$(command bash "$ASDF_EXTRAS_COMPLETION_HELPER" --standalone "${COMP_WORDS[@]:1:COMP_CWORD}")" || return 1
	while IFS= read -r candidate; do
		[[ -z "$candidate" ]] || COMPREPLY+=("$candidate")
	done <<<"$output"
}

complete -o bashdefault -o default -F _asdf_extras_standalone_complete asdf-extras

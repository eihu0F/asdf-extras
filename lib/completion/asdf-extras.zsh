_asdf_extras_standalone_complete() {
	local output candidate
	local -a candidates
	output="$(command bash "$ASDF_EXTRAS_COMPLETION_HELPER" --standalone "${words[@]:1:$((CURRENT - 1))}")" || return 1
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

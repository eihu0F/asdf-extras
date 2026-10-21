#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export ASDF_COMPLETION_REPO="$repo_dir" ASDF_COMPLETION_TEST="$test_root"
export PATH="$test_root/bin:$PATH"
mkdir -p "$test_root/bin"
cat >"$test_root/bin/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
"completion bash")
	[[ "${ASDF_COMPLETION_FAIL:-}" != generator ]] || exit 8
	[[ "${ASDF_COMPLETION_FAIL:-}" != empty ]] || exit 0
	cat <<'BASH'
native_alternate_name() {
	case "${COMP_WORDS[1]:-}" in
	install)
		if [[ $COMP_CWORD == 2 ]]; then
			COMPREPLY=(native-plugin)
		else
			COMPREPLY=(native-version)
		fi
		printf '%s\n' "${COMP_WORDS[@]}" >"$ASDF_COMPLETION_TEST/context"
		;;
	*) COMPREPLY=(native-command) ;;
	esac
	return "${ASDF_COMPLETION_NATIVE_RC:-0}"
}
complete -o bashdefault -o default -o nospace -W 'native words' -F native_alternate_name asdf
BASH
	;;
"completion zsh")
	[[ "${ASDF_COMPLETION_FAIL:-}" != generator ]] || exit 8
	printf 'compadd native-command\n'
	;;
"completion fish")
	[[ "${ASDF_COMPLETION_FAIL:-}" != generator ]] || exit 8
	printf "complete -c asdf -f -n '__fish_seen_subcommand_from version' -a native-command\n"
	;;
"plugin list")
	[[ "${ASDF_COMPLETION_FAIL:-}" != plugins ]] || exit 6
	printf 'nodejs\npython\n'
	;;
"list all nodejs")
	[[ "${ASDF_COMPLETION_FAIL:-}" != versions ]] || exit 7
	printf '20.0.0\n22.0.0\n'
	;;
*) printf 'unexpected mock invocation: %s\n' "$*" >&2; exit 9 ;;
esac
EOF
chmod +x "$test_root/bin/asdf"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

# shellcheck disable=SC2016
"$BASH" -eu -c '
	fail() { printf "FAIL: %s\n" "$*" >&2; exit 1; }
	contains() {
		case " ${COMPREPLY[*]-} " in *" $1 "*) ;; *) fail "missing $1: ${COMPREPLY[*]-}";; esac
	}
	absent() {
		case " ${COMPREPLY[*]-} " in *" $1 "*) fail "unexpected $1";; esac
	}
	run_completion() {
		COMP_WORDS=("$@")
		COMP_CWORD=$(($# - 1))
		COMP_LINE="${COMP_WORDS[*]}"
		COMP_POINT=${#COMP_LINE}
		_asdf_extras_complete asdf "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[COMP_CWORD-1]}"
	}
	code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-init" bash)"
	eval "$code"
	[[ "$_ASDF_EXTRAS_NATIVE_COMPLETE" == native_alternate_name ]] || fail "handler discovery"
	registration="$(complete -p asdf)"
	[[ "$registration" == *"-o bashdefault"* && "$registration" == *"-o default"* &&
		"$registration" == *"-o nospace"* && "$registration" == *"native words"* ]] || fail "registration options lost"
	eval "$code"
	[[ "$(complete -p asdf)" == "$registration" ]] || fail "repeated init changed registration"
	code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" bash)"
	eval "$code"
	[[ "$_ASDF_EXTRAS_NATIVE_COMPLETE" == native_alternate_name ]] || fail "recursive delegation"
	[[ "$(asdf completion bash)" == "$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf bash)" ]] || fail "initialized completion mode"
	run_completion asdf ""
	contains update
	contains native-command
	run_completion asdf version ""
	contains native-command
	ASDF_COMPLETION_NATIVE_RC=7
	if run_completion asdf version ""; then fail "native failure suppressed"; else [[ $? == 7 ]] || fail "native failure status"; fi
	unset ASDF_COMPLETION_NATIVE_RC
	code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-init" bash)"
	run_completion asdf install ""
	contains native-plugin
	contains --local
	run_completion asdf install --local nodejs ""
	contains native-version
	contains latest
	[[ "$(cat "$ASDF_COMPLETION_TEST/context")" == "$(printf "asdf\ninstall\nnodejs\n")" ]] || fail "normalized native context"
	[[ "${COMP_WORDS[*]}" == "asdf install --local nodejs " && "$COMP_CWORD" == 4 ]] || fail "completion context leaked"
	run_completion asdf install nodejs --parent ""
	contains native-version
	absent --home
	run_completion asdf update --local ""
	contains nodejs
	contains python
	absent --parent
	run_completion asdf update --version nodejs --local 2
	contains 20.0.0
	contains 22.0.0
	run_completion asdf update --plugin nodejs ""
	absent 20.0.0
	absent latest
	absent --all
	run_completion asdf update --asdf ""
	absent nodejs
	contains --plugin
	absent --asdf
	run_completion asdf update --all ""
	[[ -z "${COMPREPLY[*]-}" ]] || fail "--all accepted more targets"
	run_completion asdf update --version --
	contains --plugin
	absent --all
	ASDF_COMPLETION_FAIL=plugins
	export ASDF_COMPLETION_FAIL
	if run_completion asdf update ""; then fail "plugin failure suppressed"; fi
	ASDF_COMPLETION_FAIL=versions
	if run_completion asdf update nodejs ""; then fail "version failure suppressed"; fi
	ASDF_COMPLETION_FAIL=generator
	complete -r asdf
	if eval "$code"; then fail "native generation failure suppressed"; fi
	ASDF_COMPLETION_FAIL=empty
	if eval "$code"; then fail "empty native registration accepted"; fi
	unset ASDF_COMPLETION_FAIL
	complete -C native-external asdf
	external_registration="$(complete -p asdf)"
	if eval "$code"; then fail "non-function registration accepted"; fi
	[[ "$(complete -p asdf)" == "$external_registration" ]] || fail "external registration overwritten"
'

# shellcheck disable=SC2016
"$BASH" -eu -c '
	fail() { printf "FAIL: %s\n" "$*" >&2; exit 1; }
	eval "$(command asdf completion bash)"
	registration="$(complete -p asdf)"
	code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" bash)"
	eval "$code"
	eval "$code"
	! declare -F asdf >/dev/null || fail "completion installed command wrapper"
	! declare -F _asdf_extras_complete >/dev/null || fail "standalone loaded overlay definitions"
	[[ "$(complete -p asdf)" == "$registration" ]] || fail "native registration changed"
	for context in root plugin version shell option option-shell trailing-option; do
		case "$context" in
		root) COMP_WORDS=(asdf-extras up); expected=update ;;
		plugin) COMP_WORDS=(asdf-extras install --local n); expected=nodejs ;;
		version) COMP_WORDS=(asdf-extras update nodejs --version 22); expected=22.0.0 ;;
		shell) COMP_WORDS=(asdf-extras completion z); expected=zsh ;;
		option) COMP_WORDS=(asdf-extras completion --); expected=--asdf ;;
		option-shell) COMP_WORDS=(asdf-extras completion --asdf z); expected=zsh ;;
		trailing-option) COMP_WORDS=(asdf-extras completion bash --); expected=--asdf ;;
		esac
		COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
		_asdf_extras_standalone_complete
		[[ "${COMPREPLY[*]-}" == "$expected" ]] || fail "standalone $context"
	done
	complete -r asdf
	export ASDF_COMPLETION_FAIL=generator
	eval "$code"
	if complete -p asdf 2>/dev/null; then fail "standalone loaded native completion"; fi
	unset ASDF_COMPLETION_FAIL
	code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf bash)"
	eval "$code"
	eval "$code"
	! declare -F asdf >/dev/null || fail "--asdf installed command wrapper"
	[[ "$(complete -p asdf)" == *"-F _asdf_extras_complete"* ]] || fail "--asdf overlay missing"
	[[ "$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" bash --asdf)" == "$code" ]] || fail "option position"
'

for args in "" "--unknown bash" "bash zsh" "--asdf" "--asdf elvish" "--asdf nushell"; do
	# Test inputs are intentionally split into command arguments.
	# shellcheck disable=SC2086
	if bash "$repo_dir/lib/commands/command-completion" $args >"$test_root/output" 2>"$test_root/error"; then
		fail "accepted invalid completion arguments: $args"
	fi
	[[ ! -s "$test_root/output" && -s "$test_root/error" ]] || fail "completion argument diagnostic: $args"
done

if command -v zsh >/dev/null; then
	# shellcheck disable=SC2016
	zsh -f -c '
		setopt errexit nounset
		fail() { print -u2 "FAIL: $*"; exit 1; }
		code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" zsh)"
		eval "$code"
		eval "$code"
		(( ! $+functions[asdf] )) || fail "standalone installed wrapper"
		(( ! $+functions[_asdf_extras_complete] )) || fail "standalone loaded overlay definitions"
		[[ -z "${_comps[asdf]:-}" ]] || fail "standalone registered asdf"
		compadd() { print -rl -- "$@" >>"$ASDF_COMPLETION_TEST/zsh-candidates"; }
		words=(asdf-extras update --local nodejs 22); CURRENT=5
		_asdf_extras_standalone_complete
		grep -qx 22.0.0 "$ASDF_COMPLETION_TEST/zsh-candidates"
		code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf zsh)"
		eval "$code"
		eval "$code"
		(( ! $+functions[asdf] )) || fail "--asdf installed wrapper"
		[[ "${_comps[asdf]}" == _asdf_extras_complete ]] || fail "--asdf overlay missing"
		autoload -Uz compinit
		compinit -i -D
		compadd() { print -rl -- "$@" >>"$ASDF_COMPLETION_TEST/zsh-candidates"; }
		native_framework_handler() {
			print -r -- "${words[*]}:$CURRENT" >"$ASDF_COMPLETION_TEST/zsh-context"
			compadd native-command
		}
		compdef native_framework_handler asdf
		code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-init" zsh)"
		eval "$code"
		eval "$code"
		[[ "$_ASDF_EXTRAS_NATIVE_COMPLETE" == native_framework_handler ]] || fail "framework handler lost"
		[[ "$(asdf completion zsh)" == "$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf zsh)" ]] || fail "initialized completion mode"
		words=(asdf ""); CURRENT=2
		_asdf_extras_complete
		grep -qx update "$ASDF_COMPLETION_TEST/zsh-candidates"
		grep -qx native-command "$ASDF_COMPLETION_TEST/zsh-candidates"
		words=(asdf update --local nodejs 2); CURRENT=5
		_asdf_extras_complete
		grep -qx 22.0.0 "$ASDF_COMPLETION_TEST/zsh-candidates"
		words=(asdf install --parent nodejs ""); CURRENT=5
		_asdf_extras_complete
		[[ "$(<"$ASDF_COMPLETION_TEST/zsh-context")" == "asdf install nodejs :4" ]] || fail "normalized native context"
		[[ "${words[*]}" == "asdf install --parent nodejs " && "$CURRENT" == 5 ]] || fail "context leaked"
		words=(asdf install "" later); CURRENT=3
		_asdf_extras_complete
		[[ "$(<"$ASDF_COMPLETION_TEST/zsh-context")" == "asdf install  later:3" ]] || fail "ordinary context changed"
		native_replacement() { compadd replacement; }
		compdef native_replacement asdf
		eval "$code"
		[[ "$_ASDF_EXTRAS_NATIVE_COMPLETE" == native_replacement ]] || fail "framework re-registration"
		unfunction native_framework_handler
		unset "_comps[asdf]"
		eval "$code"
		[[ "$_ASDF_EXTRAS_NATIVE_COMPLETE" == _asdf_extras_native_complete ]] || fail "missing native fallback"
		words=(asdf version ""); CURRENT=3
		_asdf_extras_complete
		unset "_comps[asdf]"
		export ASDF_COMPLETION_FAIL=generator
		if eval "$code"; then fail "native Zsh generation failure suppressed"; fi
	'
else
	printf 'SKIP: zsh is unavailable\n'
fi

if command -v fish >/dev/null; then
	: >"$test_root/native-file"
	# shellcheck disable=SC2016
	fish --no-config -c '
		function fail
			echo "FAIL: $argv" >&2
			exit 1
		end
		function contains_candidate
			contains -- $argv[1] (complete -C "$argv[2]" | string split \t -f 1); or fail "$argv"
		end
		bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" fish | source; or fail "standalone loading"
		functions -q asdf; and fail "standalone installed wrapper"
		functions -q __asdf_extras_completion_candidates; and fail "standalone loaded overlay definitions"
		test (count (complete -c asdf)) -eq 0; or fail "standalone registered asdf"
		set -l standalone (complete -c asdf-extras)
		bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" fish | source
		test (count (complete -c asdf-extras)) -eq (count $standalone); or fail "duplicate standalone registration"
		contains_candidate update "asdf-extras up"
		contains_candidate --local "asdf-extras install --"
		contains_candidate nodejs "asdf-extras install --local n"
		contains_candidate 22.0.0 "asdf-extras update nodejs --version 22"
		contains_candidate zsh "asdf-extras completion z"
		contains_candidate --asdf "asdf-extras completion --"
		contains_candidate zsh "asdf-extras completion --asdf z"
		bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf fish | source; or fail "--asdf loading"
		functions -q asdf; and fail "--asdf installed wrapper"
		contains_candidate --version "asdf update --"
		complete -c asdf -f -n "__fish_seen_subcommand_from version" -a native-command
		bash "$ASDF_COMPLETION_REPO/lib/commands/command-init" fish | source
		set -l initialized (asdf completion fish)
		set -l expected (bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf fish)
		test "$initialized" = "$expected"; or fail "initialized completion mode"
		set -l registrations (complete -c asdf)
		bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" fish | source
		test (count (complete -c asdf)) -eq (count $registrations); or fail "duplicate registration"
		contains_candidate update "asdf up"
		contains_candidate --version "asdf update --"
		contains_candidate --local "asdf install --"
		contains_candidate nodejs "asdf update --local n"
		contains_candidate 22.0.0 "asdf update nodejs --version 2"
		contains_candidate latest "asdf install nodejs --parent l"
		contains_candidate native-command "asdf version "
		cd "$ASDF_COMPLETION_TEST"
		contains_candidate native-file "asdf exec native-"
		set -e __asdf_extras_completion_registered
		complete -e -c asdf
		bash "$ASDF_COMPLETION_REPO/lib/commands/command-init" fish | source; or fail "native Fish loading"
		contains_candidate native-command "asdf version "
		set -e __asdf_extras_completion_registered
		complete -e -c asdf
		set -gx ASDF_COMPLETION_FAIL generator
		if bash "$ASDF_COMPLETION_REPO/lib/commands/command-init" fish | source
			fail "native Fish generation failure suppressed"
		end
	'
else
	printf 'SKIP: fish is unavailable\n'
fi

printf 'completion overlay tests: PASS\n'

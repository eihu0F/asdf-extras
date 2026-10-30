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
# Stand in for the stable entry points that wrappers and completion query.
if [[ "${1:-}" == which && "${2:-}" == asdf-extras ]]; then
	printf '%s\n' "$ASDF_COMPLETION_REPO/libexec/asdf-extras"
	exit 0
fi
if [[ "${1:-}" == exec && "${2:-}" == asdf-extras ]]; then
	shift 2
	exec bash "$ASDF_COMPLETION_REPO/libexec/asdf-extras" "$@"
fi
if [[ "${1:-}" == cmd && "${2:-}" == asdf-extras ]]; then
	subcommand="$3"
	shift 3
	[[ "${1:-}" != -- ]] || shift
	exec bash "$ASDF_COMPLETION_REPO/lib/commands/command-$subcommand" "$@"
fi
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
		printf '%s\n%s\n%s\n' "$COMP_CWORD" "$COMP_LINE" "$COMP_POINT" >"$ASDF_COMPLETION_TEST/cursor"
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
"completion elvish" | "completion nushell")
	printf '# native legacy completion\n'
	;;
"plugin list")
	[[ "${ASDF_COMPLETION_FAIL:-}" != plugins ]] || exit 6
	printf 'nodejs\npython\n'
	;;
"list nodejs")
	printf '  20.0.0\n *22.0.0\n'
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
	[[ -z "${ASDF_EXTRAS_COMPLETION_ORIGIN:-}" ]] || fail "init set the completion origin"
	[[ -z "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]] || fail "init registered the overlay"
	! declare -F _asdf_extras_complete >/dev/null || fail "init defined overlay functions"
	! complete -p asdf >/dev/null 2>&1 || fail "init registered asdf completion"
	! complete -p asdf-extras >/dev/null 2>&1 || fail "init registered asdf-extras completion"
	code="$(asdf completion bash)"
	eval "$code"
	[[ "$_ASDF_EXTRAS_NATIVE_COMPLETE" == native_alternate_name ]] || fail "handler discovery"
	registration="$(complete -p asdf)"
	[[ "$registration" == *"-o bashdefault"* && "$registration" == *"-o default"* &&
		"$registration" == *"-o nospace"* && "$registration" == *"native words"* ]] || fail "registration options lost"
	eval "$code"
	[[ "$(complete -p asdf)" == "$registration" ]] || fail "repeated completion changed registration"
	code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" bash)"
	eval "$code"
	[[ "$_ASDF_EXTRAS_NATIVE_COMPLETE" == native_alternate_name ]] || fail "recursive delegation"
	[[ "$(asdf completion bash)" == "$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf bash)" ]] || fail "initialized completion mode"
	[[ "$(asdf completion nushell)" == "$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf --wrappers nushell)" ]] || fail "Nushell combined mode"
	for shell in elvish; do
		[[ "$(asdf completion "$shell")" == "$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf "$shell")" ]] || fail "Elvish combined completion forwarding"
	done
	run_completion asdf ""
	contains update
	contains get
	contains shell
	contains native-command
	run_completion asdf shell ""
	contains --unset
	contains nodejs
	absent native-command
	run_completion asdf shell nodejs ""
	contains 22.0.0
	contains system
	contains 20.0.0
	run_completion asdf shell --unset ""
	contains python
	absent --unset
	run_completion asdf get ""
	contains nodejs
	contains --local
	absent native-command
	run_completion asdf get --parent ""
	contains python
	absent --local
	run_completion asdf get nodejs ""
	absent 22.0.0
	run_completion asdf version ""
	contains native-command
	ASDF_COMPLETION_NATIVE_RC=7
	if run_completion asdf version ""; then fail "native failure suppressed"; else [[ $? == 7 ]] || fail "native failure status"; fi
	unset ASDF_COMPLETION_NATIVE_RC
	code="$(asdf completion bash)"
	run_completion asdf install ""
	contains native-plugin
	contains --local
	run_completion asdf install --local nodejs ""
	contains native-version
	contains latest
	[[ "$(cat "$ASDF_COMPLETION_TEST/context")" == "$(printf "asdf\ninstall\nnodejs\n")" ]] || fail "normalized native context"
	[[ "${COMP_WORDS[*]}" == "asdf install --local nodejs " && "$COMP_CWORD" == 4 ]] || fail "completion context leaked"
	COMP_WORDS=(asdf install --local n 22.0.0 --parent)
	COMP_CWORD=3
	COMP_LINE="asdf install --local n 22.0.0 --parent"
	COMP_POINT=22
	_asdf_extras_complete asdf n --local
	[[ "$(cat "$ASDF_COMPLETION_TEST/context")" == "$(printf "asdf\ninstall\nn\n22.0.0\n")" ]] || fail "post-cursor arguments lost"
	[[ "$(cat "$ASDF_COMPLETION_TEST/cursor")" == "$(printf "2\nasdf install n 22.0.0\n14\n")" ]] || fail "normalized cursor"
	[[ "$COMP_CWORD" == 3 && "$COMP_LINE" == "asdf install --local n 22.0.0 --parent" && "$COMP_POINT" == 22 ]] || fail "cursor context leaked"
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
	contains --use-latest
	absent --asdf
	run_completion asdf update --all ""
	contains --local
	contains --home
	absent --version
	absent --use-latest
	absent nodejs
	run_completion asdf update --all --local ""
	[[ -z "${COMPREPLY[*]-}" ]] || fail "--all with scope accepted more targets"
	run_completion asdf update --version --
	contains --plugin
	contains --use-latest
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

output="$(bash "$repo_dir/libexec/asdf-extras" completion --candidates --standalone completion elvish --)"
[[ "$output" == --asdf ]] || fail "Elvish combined mode missing"
output="$(bash "$repo_dir/libexec/asdf-extras" completion --candidates --standalone update --all --)"
[[ "$output" == "$(printf '%s\n' --home --parent --local)" ]] || fail "standalone --all scopes"
output="$(bash "$repo_dir/libexec/asdf-extras" completion --candidates --standalone "")"
[[ "$output" == *get* ]] || fail "get missing from subcommand candidates"
output="$(bash "$repo_dir/libexec/asdf-extras" completion --candidates --standalone help g)"
[[ "$output" == get ]] || fail "get help topic missing"
output="$(bash "$repo_dir/libexec/asdf-extras" completion --candidates --standalone help s)"
[[ "$output" == shell ]] || fail "shell help topic missing"
# Every position after the plugin completes a version, and --replace is offered once.
candidates() { bash "$repo_dir/libexec/asdf-extras" completion --candidates --standalone "$@"; }
for subcommand in install update; do
	output="$(candidates "$subcommand" nodejs 22.0.0 "")"
	[[ "$output" == *latest* && "$output" == *system* && "$output" == *20.0.0* ]] || fail "$subcommand second version: $output"
	[[ "$output" == *--replace* ]] || fail "$subcommand --replace not offered: $output"
	output="$(candidates "$subcommand" --replace nodejs "")"
	[[ "$output" != *--replace* ]] || fail "$subcommand offered --replace twice"
done
[[ "$(candidates install --delegated nodejs 22.0.0 s)" == system ]] || fail "delegated install lacks later versions"
# Words typed on the command line belong to the query, even --help.
output="$(bash "$repo_dir/libexec/asdf-extras" completion --candidates --standalone update --help)"
[[ -z "$output" ]] || fail "--candidates treated a typed --help as a request for help"

# shellcheck disable=SC2016
"$BASH" -eu -c '
	fail() { printf "FAIL: %s\n" "$*" >&2; exit 1; }
	eval "$(command asdf completion bash)"
	registration="$(complete -p asdf)"
	code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" bash)"
	eval "$code"
	eval "$code"
	standalone_registration="$(complete -p asdf-extras)"
	[[ "$standalone_registration" == *"-o bashdefault"* && "$standalone_registration" == *"-o default"* ]] || fail "standalone registration options lost"
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

for args in "" "--unknown bash" "bash zsh" "--asdf"; do
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
		origin_before="${ASDF_EXTRAS_COMPLETION_ORIGIN:-}"
		code="$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-init" zsh)"
		eval "$code"
		eval "$code"
		[[ "${_comps[asdf]}" == native_framework_handler ]] || fail "init replaced the framework handler"
		[[ -z "${ASDF_EXTRAS_COMPLETION_ORIGIN:-}" || "$ASDF_EXTRAS_COMPLETION_ORIGIN" == "$origin_before" ]] || fail "init changed the completion origin"
		code="$(asdf completion zsh)"
		eval "$code"
		eval "$code"
		[[ "$_ASDF_EXTRAS_NATIVE_COMPLETE" == native_framework_handler ]] || fail "framework handler lost"
		[[ "$(asdf completion zsh)" == "$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf zsh)" ]] || fail "initialized completion mode"
		[[ "$(asdf completion nushell)" == "$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf --wrappers nushell)" ]] || fail "Nushell combined mode"
		for shell in elvish; do
			[[ "$(asdf completion "$shell")" == "$(bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf "$shell")" ]] || fail "Elvish combined completion forwarding"
		done
		words=(asdf ""); CURRENT=2
		_asdf_extras_complete
		grep -qx update "$ASDF_COMPLETION_TEST/zsh-candidates"
		grep -qx get "$ASDF_COMPLETION_TEST/zsh-candidates"
		grep -qx shell "$ASDF_COMPLETION_TEST/zsh-candidates"
		grep -qx native-command "$ASDF_COMPLETION_TEST/zsh-candidates"
		: >"$ASDF_COMPLETION_TEST/zsh-candidates"
		words=(asdf shell nodejs 2); CURRENT=4
		_asdf_extras_complete
		grep -qx 22.0.0 "$ASDF_COMPLETION_TEST/zsh-candidates"
		: >"$ASDF_COMPLETION_TEST/zsh-candidates"
		words=(asdf get --parent n); CURRENT=5
		_asdf_extras_complete
		grep -qx nodejs "$ASDF_COMPLETION_TEST/zsh-candidates"
		words=(asdf update --local nodejs 2); CURRENT=5
		_asdf_extras_complete
		grep -qx 22.0.0 "$ASDF_COMPLETION_TEST/zsh-candidates"
		words=(asdf install --parent nodejs ""); CURRENT=5
		_asdf_extras_complete
		[[ "$(<"$ASDF_COMPLETION_TEST/zsh-context")" == "asdf install nodejs :4" ]] || fail "normalized native context"
		[[ "${words[*]}" == "asdf install --parent nodejs " && "$CURRENT" == 5 ]] || fail "context leaked"
		words=(asdf install --parent n 22.0.0 --local); CURRENT=4
		_asdf_extras_complete
		[[ "$(<"$ASDF_COMPLETION_TEST/zsh-context")" == "asdf install n 22.0.0:3" ]] || fail "post-cursor arguments lost"
		[[ "${words[*]}" == "asdf install --parent n 22.0.0 --local" && "$CURRENT" == 4 ]] || fail "middle cursor context leaked"
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
		set -l nu_actual (asdf completion nushell)
		set -l nu_expected (bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf --wrappers nushell)
		test "$nu_actual" = "$nu_expected"; or fail "Nushell combined mode"
		for shell in elvish
			set -l actual (asdf completion $shell)
			set -l combined (bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" --asdf $shell)
			test "$actual" = "$combined"; or fail "Elvish combined completion forwarding"
		end
		set -l registrations (complete -c asdf)
		bash "$ASDF_COMPLETION_REPO/lib/commands/command-completion" fish | source
		test (count (complete -c asdf)) -eq (count $registrations); or fail "duplicate registration"
		contains_candidate update "asdf up"
		contains_candidate get "asdf g"
		contains_candidate nodejs "asdf get --parent n"
		contains_candidate shell "asdf sh"
		contains_candidate --unset "asdf shell --"
		contains_candidate 22.0.0 "asdf shell nodejs 2"
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
		asdf completion fish | source; or fail "native Fish loading"
		contains_candidate native-command "asdf version "
		set -e __asdf_extras_completion_registered
		complete -e -c asdf
		set -gx ASDF_COMPLETION_FAIL generator
		if asdf completion fish | source
			fail "native Fish generation failure suppressed"
		end
	'
else
	printf 'SKIP: fish is unavailable\n'
fi

# Wrappers and completion queries reach extras through its entry points, so they
# keep working after the runtime that generated them is removed.
removed_runtime="$test_root/removed-runtime"
for shell in bash zsh fish; do
	command -v "$shell" >/dev/null || continue
	rm -rf "$removed_runtime"
	mkdir -p "$removed_runtime"
	cp -R "$repo_dir/lib" "$repo_dir/libexec" "$removed_runtime/"
	query=_asdf_extras_query
	[[ "$shell" != fish ]] || query=__asdf_extras_query
	{
		bash "$removed_runtime/libexec/asdf-extras" init "$shell"
		bash "$removed_runtime/libexec/asdf-extras" completion "$shell"
		printf 'rm -rf %q\n' "$removed_runtime"
		printf '%s --standalone "" >%q\n' "$query" "$test_root/removed.candidates"
		printf 'asdf completion bash >%q\n' "$test_root/removed.completion"
	} >"$test_root/removed.$shell"
	"$shell" "$test_root/removed.$shell" || fail "$shell: entry points failed after runtime removal"
	grep -Fx completion "$test_root/removed.candidates" >/dev/null || fail "$shell: completion query used a removed runtime"
	grep -F "$repo_dir" "$test_root/removed.completion" >/dev/null || fail "$shell: wrapper did not reach the selected runtime"
	[[ ! -e "$removed_runtime" ]] || fail "$shell: runtime was not removed"
done

# init enables command wrappers only; completion is a separate, explicit step.
for shell in bash zsh fish elvish nushell; do
	init_output="$(bash "$repo_dir/lib/commands/command-init" "$shell")"
	for marker in ASDF_EXTRAS_COMPLETION_ORIGIN lib/completion/ nushell-completion; do
		[[ "$init_output" != *"$marker"* ]] || fail "init $shell emitted completion: $marker"
	done
	[[ "$init_output" == *ASDF_EXTRAS_INIT_ORIGIN* ]] || fail "init $shell lost the command wrapper"
done
nushell_wrappers="$(bash "$repo_dir/lib/commands/command-completion" --asdf --wrappers nushell)"
[[ "$nushell_wrappers" == *"lib/init/nushell-completion.nu"* ]] || fail "--wrappers did not redefine the Nushell wrappers"
[[ "$(bash "$repo_dir/lib/commands/command-completion" --asdf nushell)" != *nushell-completion* ]] ||
	fail "combined Nushell completion defined wrappers without --wrappers"
for shell in bash zsh fish elvish; do
	[[ "$(bash "$repo_dir/lib/commands/command-completion" --asdf --wrappers "$shell")" == "$(bash "$repo_dir/lib/commands/command-completion" --asdf "$shell")" ]] ||
		fail "--wrappers changed $shell completion"
done
if bash "$repo_dir/lib/commands/command-completion" --wrappers nushell >"$test_root/output" 2>"$test_root/error"; then
	fail "accepted --wrappers without --asdf"
fi
[[ ! -s "$test_root/output" && -s "$test_root/error" ]] || fail "--wrappers diagnostic"

printf 'completion overlay tests: PASS\n'

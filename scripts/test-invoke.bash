#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export ASDF_INVOKE_ROOT="$test_root" ASDF_INVOKE_REPO="$repo_dir"
export PATH="$test_root/bin:$PATH"
mkdir -p "$test_root/bin"
unset ASDF_A_VERSION ASDF_B_VERSION ASDF_C_VERSION

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

# A fake runtime: it speaks the invoke contract the initialized wrapper relies on,
# and emits whatever control lines the scenario asks for.
cat >"$test_root/bin/asdf-extras" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '<%s>\n' "$@" >"$ASDF_INVOKE_ROOT/runtime-args"
case "$ASDF_INVOKE_SCENARIO" in
silent) exit "${ASDF_INVOKE_RC:-0}" ;;
passthrough)
	printf 'handled\n' >"$ASDF_EXTRAS_CONTROL"
	cat
	printf 'to stderr\n' >&2
	exit "${ASDF_INVOKE_RC:-0}"
	;;
nomarker)
	printf 'set ASDF_A_VERSION early\n' >"$ASDF_EXTRAS_CONTROL"
	exit 0
	;;
control)
	{
		printf 'handled\n'
		printf 'set ASDF_A_VERSION 3.12.0 system\n'
		printf 'set PATH /evil\n'
		printf 'set ASDF_B_VERSION\n'
		printf 'set ASDF_lower_VERSION x\n'
		printf 'export ASDF_B_VERSION nope\n'
		printf 'set ASDF_B_VERSION two words\n'
		printf 'unset ASDF_C_VERSION\n'
		printf 'unset HOME\n'
		printf 'garbage\n'
	} >"$ASDF_EXTRAS_CONTROL"
	exit "${ASDF_INVOKE_RC:-0}"
	;;
esac
EOF
chmod +x "$test_root/bin/asdf-extras"

# Native asdf: resolves the fake runtime unless told otherwise.
cat >"$test_root/bin/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == which && "${2:-}" == asdf-extras ]]; then
	[[ "${ASDF_INVOKE_RESOLVE:-yes}" == yes ]] || exit 1
	printf '%s\n' "$ASDF_INVOKE_ROOT/bin/asdf-extras"
	exit 0
fi
if [[ "${1:-}" == cmd ]]; then
	printf '<%s>\n' "$@" >"$ASDF_INVOKE_ROOT/cmd-args"
	exec "$ASDF_INVOKE_ROOT/bin/asdf-extras" invoke "${@:5}"
fi
printf 'NATIVE: %s\n' "$*"
EOF
chmod +x "$test_root/bin/asdf"

# Runs a request in a shell that loaded the initialization twice.
run_shell() {
	local shell="$1" request="$2" init_file
	case "$shell" in
	bash | zsh)
		init_file=bash.sh
		[[ "$shell" != zsh ]] || init_file=zsh.zsh
		printf "source \"\$ASDF_INVOKE_REPO/lib/init/%s\"\nsource \"\$ASDF_INVOKE_REPO/lib/init/%s\"\n%s\n" \
			"$init_file" "$init_file" "$request" >"$test_root/test"
		"$shell" "$test_root/test"
		;;
	fish)
		printf "source \"\$ASDF_INVOKE_REPO/lib/init/fish.fish\"\nsource \"\$ASDF_INVOKE_REPO/lib/init/fish.fish\"\n%s\n" "$request" >"$test_root/test"
		fish "$test_root/test"
		;;
	esac
}

for shell in bash zsh fish; do
	if ! command -v "$shell" >/dev/null; then
		printf 'SKIP: %s is unavailable\n' "$shell"
		continue
	fi
	# shellcheck disable=SC2016
	case "$shell" in
	fish) show_vars='echo "A=[$ASDF_A_VERSION] B=[$ASDF_B_VERSION] C=[$ASDF_C_VERSION] P1=[$PATH[1]] HOME=[$HOME]"' ;;
	*) show_vars='echo "A=[${ASDF_A_VERSION-}] B=[${ASDF_B_VERSION-}] C=[${ASDF_C_VERSION-}] P1=[${PATH%%:*}] HOME=[$HOME]"' ;;
	esac
	export ASDF_EXTRAS_INIT_ORIGIN=installed

	# The runtime receives the shell, the protocol and the arguments as data.
	ASDF_INVOKE_SCENARIO=silent run_shell "$shell" "asdf -x 'two words' ''" >/dev/null 2>&1 || true
	[[ "$(tr '\n' ' ' <"$test_root/runtime-args")" == "<invoke> <--shell> <$shell> <--protocol> <1> <--> <-x> <two words> <> " ]] ||
		fail "$shell: invoke arguments: $(tr '\n' ' ' <"$test_root/runtime-args")"

	# Output, standard input and the exit status pass through untouched.
	out="$(printf 'piped\n' | ASDF_INVOKE_SCENARIO=passthrough ASDF_INVOKE_RC=5 run_shell "$shell" 'asdf current' 2>"$test_root/stderr")" || true
	[[ "$out" == piped* ]] || fail "$shell: stdin or stdout lost: $out"
	grep -Fx 'to stderr' "$test_root/stderr" >/dev/null || fail "$shell: stderr lost"
	ASDF_INVOKE_SCENARIO=passthrough ASDF_INVOKE_RC=5 run_shell "$shell" 'asdf current' </dev/null >/dev/null 2>&1 && fail "$shell: exit status lost"

	# Without the marker nothing ran, so native asdf runs instead, once.
	out="$(ASDF_INVOKE_SCENARIO=silent run_shell "$shell" 'asdf current python')"
	[[ "$out" == 'NATIVE: current python' ]] || fail "$shell: no native fallback without the marker: $out"
	out="$(ASDF_INVOKE_SCENARIO=nomarker run_shell "$shell" "asdf current python
$show_vars")"
	[[ "$out" == 'NATIVE: current python'* && "$out" == *"A=[]"* ]] || fail "$shell: lines before the marker were trusted: $out"
	out="$(ASDF_INVOKE_RESOLVE=no ASDF_INVOKE_SCENARIO=control run_shell "$shell" 'asdf current python')"
	[[ "$out" == 'NATIVE: current python' ]] || fail "$shell: no native fallback without a runtime: $out"

	# Only valid ASDF_ variables are applied; everything else is ignored.
	export ASDF_C_VERSION=gone
	out="$(ASDF_INVOKE_SCENARIO=control run_shell "$shell" "asdf shell python 1
$show_vars
printenv ASDF_A_VERSION")"
	unset ASDF_C_VERSION
	[[ "$out" == *"A=[3.12.0 system] B=[two words] C=[]"* ]] || fail "$shell: control lines: $out"
	[[ "$out" == *"P1=[$test_root/bin] HOME=[$HOME]"* ]] || fail "$shell: a non-ASDF variable was changed: $out"
	[[ "$out" == *"3.12.0 system"* ]] || fail "$shell: the variable was not exported"

	# A failed command changes nothing and keeps its status.
	out="$(ASDF_INVOKE_SCENARIO=control ASDF_INVOKE_RC=3 run_shell "$shell" "asdf shell python 1
$show_vars" 2>&1)"
	[[ "$out" == *"A=[] B=[] C=[]"* ]] || fail "$shell: control lines applied after a failure: $out"

	# The plugin checkout entry point takes the same contract through asdf cmd.
	export ASDF_EXTRAS_INIT_ORIGIN=plugin
	ASDF_INVOKE_SCENARIO=silent run_shell "$shell" "asdf get python" >/dev/null 2>&1 || true
	grep -Fx '<invoke>' "$test_root/runtime-args" >/dev/null || fail "$shell: plugin entry point"
	[[ "$(tr '\n' ' ' <"$test_root/cmd-args")" == "<cmd> <asdf-extras> <invoke> <--> <--shell> <$shell> <--protocol> <1> <--> <get> <python> " ]] ||
		fail "$shell: asdf cmd arguments: $(tr '\n' ' ' <"$test_root/cmd-args")"
	unset ASDF_EXTRAS_INIT_ORIGIN
done

# invoke itself routes like the wrapper used to.
export ASDF_EXTRAS_ORIGIN=installed
invoke() {
	bash "$repo_dir/libexec/asdf-extras" invoke --shell bash --protocol 1 -- "$@"
}
mkdir -p "$test_root/home"
printf 'python 3.12.0 system\n' >"$test_root/home/.tool-versions"
[[ "$(HOME="$test_root/home" invoke get python)" == '3.12.0 system' ]] || fail "invoke get"
[[ "$(invoke current python)" == 'NATIVE: current python' ]] || fail "invoke native routing"
[[ "$(invoke install nodejs 22)" == 'NATIVE: install nodejs 22' ]] || fail "unscoped install must stay native"
invoke shell --help >"$test_root/help"
grep -q 'asdf-extras shell' "$test_root/help" || fail "invoke shell --help"
for bad in "--shell" "--shell vim --protocol 1 --" "--shell bash --protocol x --" "--shell bash --protocol 1 --bogus"; do
	# shellcheck disable=SC2086
	if bash "$repo_dir/libexec/asdf-extras" invoke $bad >/dev/null 2>&1; then
		fail "invoke accepted: $bad"
	fi
done
# The completion query tells the glue what to do with native completion.
query() {
	bash "$repo_dir/libexec/asdf-extras" invoke --complete --shell bash --protocol 1 "$@"
}
[[ "$(query --cword 1 -- asdf "")" == "$(printf 'native original\nupdate\nget\nshell')" ]] || fail "completion: root candidates"
[[ "$(query --cword 1 -- asdf cur)" == 'native original' ]] || fail "completion: native command is left to native completion"
[[ "$(query --cword 2 -- asdf current n)" == 'native original' ]] || fail "completion: native command arguments"
[[ "$(query --cword 3 -- asdf install --local "")" == "$(printf 'native drop 2\n--replace')" ]] || fail "completion: install drops the scope flag"
[[ "$(query --cword 3 -- asdf install --local "" --replace)" == "$(printf 'native drop 2 4\n--replace')" ]] || fail "completion: install drops flags after the cursor"
[[ "$(query --cword 2 -- asdf update --)" == native\ none* ]] || fail "completion: update is left to extras"
[[ "$(query --standalone --cword 1 -- asdf-extras g)" == "$(printf 'native none\nget')" ]] || fail "completion: standalone"
if query --cword x -- asdf >/dev/null 2>&1; then fail "completion accepted an invalid cword"; fi
# Without the control channel, shell must explain and fail, not claim success.
if invoke shell python 1 >/dev/null 2>"$test_root/error"; then
	fail "invoke shell succeeded without a control file"
fi
grep -q 'initialized shell' "$test_root/error" || fail "invoke shell did not explain"
# With it, shell validates in the runtime and only then asks for a change.
: >"$test_root/control"
ASDF_EXTRAS_CONTROL="$test_root/control" invoke shell my-tool 1.0 system
[[ "$(<"$test_root/control")" == "$(printf 'handled\nset ASDF_MY_TOOL_VERSION 1.0 system')" ]] || fail "shell control lines"
for bad in "" "python" "python 'bad version'" "-x 1" "--unset" "--unset a b"; do
	: >"$test_root/control"
	# shellcheck disable=SC2086
	if eval "ASDF_EXTRAS_CONTROL='$test_root/control' invoke shell $bad" >/dev/null 2>&1; then
		fail "shell accepted: $bad"
	fi
	[[ "$(<"$test_root/control")" == handled ]] || fail "shell wrote a change for: $bad"
done

printf 'invoke contract tests: PASS\n'

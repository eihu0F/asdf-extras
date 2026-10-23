#!/usr/bin/env bash

set -euo pipefail

if ! command -v elvish >/dev/null; then
	printf 'SKIP: Elvish is unavailable (tested with 0.21.0)\n'
	exit 0
fi
command -v script >/dev/null || {
	printf 'ERROR: Elvish editor tests require the util-linux script command\n' >&2
	exit 1
}
command -v timeout >/dev/null || {
	printf 'ERROR: Elvish editor tests require the coreutils timeout command\n' >&2
	exit 1
}
run_elvish() {
	timeout 30 script -qec "$(command -v elvish) -rc '$1'" "$2"
}
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export ASDF_ELVISH_TEST_ROOT="$test_root"
export PATH="$test_root/bin:$PATH"
export HOME="$test_root/home"
export XDG_CONFIG_HOME="$test_root/config"
export XDG_DATA_HOME="$test_root/data"
mkdir -p "$test_root/bin" "$HOME"
ln -s "$repo_dir" "$test_root/extra's runtime"
repo_dir="$test_root/extra's runtime"
cd "$test_root"
cat >"$test_root/bin/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
"completion elvish")
	printf 'completion elvish\n' >>"$ASDF_ELVISH_TEST_ROOT/native.log"
	[[ "${ASDF_ELVISH_FAILURE:-}" != generator ]] || exit 8
	case "${ASDF_ELVISH_FAILURE:-}" in
	empty) exit 0 ;;
	missing) printf '# no handler\n'; exit 0 ;;
	malformed) printf 'fn broken {\n'; exit 0 ;;
	registered)
		printf 'set edit:completion:arg-completer[asdf] = {|@words| put native-generated }\n'
		exit 0
		;;
	invalid)
		printf 'set edit:completion:arg-completer[asdf] = 42\n'
		exit 0
		;;
	esac
	printf 'fn arg-completer {|@words| put native-generated }\n'
	;;
"plugin list")
	[[ "${ASDF_ELVISH_FAILURE:-}" != query ]] || exit 9
	printf 'nodejs\npython\n'
	;;
"list all nodejs")
	[[ "${ASDF_ELVISH_FAILURE:-}" != query ]] || exit 9
	printf '22.0.0\n24.0.0\n'
	;;
*) printf '%s\n' "$*" >>"$ASDF_ELVISH_TEST_ROOT/native.log" ;;
esac
EOF
chmod +x "$test_root/bin/asdf"
bash "$repo_dir/lib/commands/command-completion" elvish >"$test_root/standalone.elv"
bash "$repo_dir/lib/commands/command-completion" --asdf elvish >"$test_root/combined.elv"
bash "$repo_dir/lib/commands/command-init" elvish >"$test_root/init.elv"
cat >"$test_root/dispatch.bash" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ASDF_ELVISH_TEST_ROOT/dispatch.log"
EOF

{
	printf 'try {\n'
	cat "$test_root/standalone.elv"
	cat <<'EOF'
if (has-key $edit:completion:arg-completer asdf) {
	fail 'standalone changed native registration'
}
fn check {|expected @words|
	var result = [($edit:completion:arg-completer[$words[0]] $@words)]
	if (not (has-value $result $expected)) {
		fail 'missing '$expected' from '(to-string $result)
	}
}
check update asdf-extras up
check nodejs asdf-extras install --local n
check 24.0.0 asdf-extras update nodejs --version 24
check elvish asdf-extras completion --asdf el
var standalone = $edit:completion:arg-completer[asdf-extras]
EOF
	cat "$test_root/standalone.elv"
	cat <<'EOF'
if (not (is $standalone $edit:completion:arg-completer[asdf-extras])) {
	fail 'standalone registration is not idempotent'
}
EOF
	cat "$test_root/combined.elv"
	cat <<'EOF'
check native-generated asdf version ''
var native-input = []
var native-handler = {|@words|
	set native-input = $words
	if (eq $words[1] broken) { fail 'native-handler-failure' }
	if (eq $words[1] install) {
		put (edit:complex-candidate 22.0.0 &display='native version')
	} else {
		put native-existing
	}
}
set edit:completion:arg-completer[asdf] = $native-handler
EOF
	cat "$test_root/combined.elv"
	cat <<'EOF'
var wrapper = $edit:completion:arg-completer[asdf]
EOF
	cat "$test_root/combined.elv"
	cat <<'EOF'
if (not (is $wrapper $edit:completion:arg-completer[asdf])) { fail 'wrappers stacked' }
check native-existing asdf current ''
var existing = $edit:completion:arg-completer[asdf]
eval (e:cat $E:ASDF_ELVISH_TEST_ROOT'/standalone.elv' | slurp)
if (not (is $existing $edit:completion:arg-completer[asdf])) {
	fail 'standalone replaced an existing native registration'
}
if (not-eq $native-input [asdf current '']) { fail 'ordinary context changed' }
check update asdf ''
check --local asdf update --all --
check nodejs asdf update --local n
check 24.0.0 asdf update --version nodejs --local 24
var result = [($edit:completion:arg-completer[asdf] asdf install --parent nodejs '')]
if (not-eq $native-input [asdf install nodejs '']) { fail 'scope context not normalized' }
if (not (has-value $result latest)) { fail 'latest missing' }
if (eq (kind-of $result[0]) string) { fail 'native rich candidate flattened' }
$edit:completion:arg-completer[asdf] asdf install --local 'plugin with spaces' 'version with spaces' | each {|candidate| }
if (not-eq $native-input [asdf install 'plugin with spaces' 'version with spaces']) {
	fail 'decoded quoted arguments changed'
}
try {
	$edit:completion:arg-completer[asdf] asdf broken ''
	fail 'native failure was suppressed'
} catch err {
	if (not-eq $err[reason][content] native-handler-failure) { fail $err }
}
EOF
	cat "$test_root/init.elv"
	cat "$test_root/init.elv"
	# init does not load completion; enable it afterward, as the shell guide does.
	cat "$test_root/combined.elv"
	cat "$test_root/combined.elv"
	cat <<'EOF'
set-env ASDF_EXTRAS_DISPATCHER $E:ASDF_ELVISH_TEST_ROOT'/dispatch.bash'
asdf install --local nodejs 22.0.0
asdf update --version nodejs
asdf completion elvish
asdf current 'plugin with spaces'
check native-existing asdf current ''
set-env ASDF_ELVISH_FAILURE query
for words [[asdf-extras install ''] [asdf-extras install nodejs ''] [asdf update ''] [asdf update nodejs '']] {
	var query-failed = $false
	try {
		$edit:completion:arg-completer[$words[0]] $@words | each {|candidate| }
	} catch err {
		set query-failed = $true
		echo 'query failure propagated'
	}
	if (not $query-failed) { fail 'query failure was suppressed' }
}
set-env ASDF_EXTRAS_COMPLETION_HELPER $E:ASDF_ELVISH_TEST_ROOT'/missing-helper'
var helper-failed = $false
try {
	$edit:completion:arg-completer[asdf] asdf install '' | each {|candidate| }
} catch err {
	set helper-failed = $true
}
if (not $helper-failed) { fail 'delegated helper failure was suppressed' }
echo 'Elvish completion tests: PASS'
} catch err {
	echo $err >&2
	exit 1
}
exit
EOF
} >"$test_root/test.elv"
if grep -q 'ASDF_EXTRAS_COMPLETION_HELPER\|asdf-extras-load-completion' "$test_root/init.elv"; then
	printf 'FAIL: init emitted completion\n' >&2
	exit 1
fi
run_elvish "$test_root/test.elv" "$test_root/transcript" </dev/null
grep -q 'Elvish completion tests: PASS' "$test_root/transcript"
grep -q 'Elvish completion query failed' "$test_root/transcript"
[[ "$(cat "$test_root/dispatch.log")" == "$(printf '%s\n' 'install --local nodejs 22.0.0' 'update --version nodejs' 'completion --asdf --wrappers elvish')" ]]
[[ "$(cat "$test_root/native.log")" == "$(printf '%s\n' 'completion elvish' 'current plugin with spaces')" ]]

cat >"$test_root/eval.elv" <<'EOF'
try {
	var asdf~ = $nil
	eval (e:cat $E:ASDF_ELVISH_TEST_ROOT'/init.elv' | slurp) &on-end={|ns| set asdf~ = $ns[asdf~]}
	set-env ASDF_EXTRAS_DISPATCHER $E:ASDF_ELVISH_TEST_ROOT'/dispatch.bash'
	asdf install --local nodejs 22.0.0
	eval (e:cat $E:ASDF_ELVISH_TEST_ROOT'/init.elv' | slurp) &on-end={|ns| set asdf~ = $ns[asdf~]}
	set-env ASDF_EXTRAS_DISPATCHER $E:ASDF_ELVISH_TEST_ROOT'/dispatch.bash'
	asdf completion elvish
	eval (e:cat $E:ASDF_ELVISH_TEST_ROOT'/combined.elv' | slurp)
	if (not-eq [($edit:completion:arg-completer[asdf] asdf current '')] [native-generated]) {
		fail 'eval setup lost native completion'
	}
	echo 'Elvish eval setup: PASS'
} catch err {
	echo $err >&2
	exit 1
}
exit
EOF
ASDF_ELVISH_FAILURE=registered run_elvish "$test_root/eval.elv" "$test_root/eval.log" </dev/null
grep -q 'Elvish eval setup: PASS' "$test_root/eval.log"
[[ "$(tail -n 2 "$test_root/dispatch.log")" == "$(printf '%s\n' 'install --local nodejs 22.0.0' 'completion --asdf --wrappers elvish')" ]]

cat >"$test_root/bin/asdf-extras" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ASDF_ELVISH_TEST_ROOT/tab.log"
EOF
chmod +x "$test_root/bin/asdf-extras"
cat >"$test_root/tab.elv" <<'EOF'
var asdf~ = $nil
try {
	eval (e:cat $E:ASDF_ELVISH_TEST_ROOT'/init.elv' | slurp) &on-end={|ns| set asdf~ = $ns[asdf~]}
	set-env ASDF_EXTRAS_DISPATCHER $E:ASDF_ELVISH_TEST_ROOT'/dispatch.bash'
	eval (e:cat $E:ASDF_ELVISH_TEST_ROOT'/combined.elv' | slurp)
} catch err {
	echo $err >&2
	exit 1
}
EOF
printf 'asdf-extras up\t\n\nasdf up\t\n\nexit\n' |
	run_elvish "$test_root/tab.elv" "$test_root/tab-transcript" >"$test_root/tab-output"
[[ "$(cat "$test_root/tab.log")" == update ]]
[[ "$(tail -n 1 "$test_root/dispatch.log")" == update ]]

for failure in generator empty missing malformed invalid; do
	{
		printf 'try {\n'
		cat "$test_root/combined.elv"
		printf "fail 'native loading failure suppressed'\n} catch err { echo 'EXPECTED-FAILURE' }\nexit\n"
	} >"$test_root/failure.elv"
	ASDF_ELVISH_FAILURE="$failure" run_elvish "$test_root/failure.elv" "$test_root/failure.log" </dev/null
	grep -q EXPECTED-FAILURE "$test_root/failure.log"
	grep -q 'asdf-extras:.*native Elvish completion' "$test_root/failure.log"
done

{
	printf "try {\nset edit:completion:arg-completer[asdf] = 42\nvar failed = \$false\ntry {\n"
	cat "$test_root/combined.elv"
	printf "} catch err { set failed = \$true }\n"
	printf "if (not \$failed) { fail 'invalid registration accepted' }\n"
	printf "if (not-eq \$edit:completion:arg-completer[asdf] 42) { fail 'invalid registration changed' }\n"
	printf "echo 'Invalid registration preserved: PASS'\n} catch err { echo \$err >&2; exit 1 }\nexit\n"
} >"$test_root/invalid.elv"
run_elvish "$test_root/invalid.elv" "$test_root/invalid.log" </dev/null
grep -q 'Invalid registration preserved: PASS' "$test_root/invalid.log"

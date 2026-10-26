#!/usr/bin/env bash

set -euo pipefail

if ! command -v nu >/dev/null; then
	printf 'SKIP: Nushell is unavailable (requires 0.116.1 or newer)\n'
	exit 0
fi
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export ASDF_NU_TEST_ROOT="$test_root" ASDF_NU_REPO="$repo_dir"
export PATH="$test_root/bin:$PATH"
mkdir -p "$test_root/bin"
cat >"$test_root/bin/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Stand in for the stable entry points that wrappers and completion query.
extras_entry=""
if [[ "${1:-}" == exec && "${2:-}" == asdf-extras ]]; then
	shift 2
	extras_entry=installed
elif [[ "${1:-}" == cmd && "${2:-}" == asdf-extras ]]; then
	shift 2
	extras_entry=plugin
	subcommand="$1"
	shift
	[[ "${1:-}" != -- ]] || shift
	set -- "$subcommand" "$@"
fi
if [[ -n "$extras_entry" ]]; then
	# Queries run for real; command wrappers only record what they dispatched.
	if [[ "$1" == __complete ]]; then
		if [[ "${ASDF_NU_QUERY_FAILURE:-}" == yes ]]; then
			printf 'candidate-query-failed\n' >&2
			exit 7
		fi
		exec bash "$ASDF_NU_REPO/libexec/asdf-extras" "$@"
	fi
	printf '%s\n' "$*" >>"$ASDF_NU_TEST_ROOT/dispatch.log"
	exit 0
fi
case "$*" in
"completion nushell")
	[[ "${ASDF_NU_FAILURE:-}" != generator ]] || exit 8
	[[ "${ASDF_NU_FAILURE:-}" != empty ]] || exit 0
	cat <<'NU'
module native {
	def root [token: record] { [plugin install current update native-marker] }
	def plugins [token: record] { [nodejs python] }
	def versions [token: record] { [{value: "22.0.0", description: "Native version"}] }
	export extern asdf [command?: string@root]
	export extern "asdf install" [plugin?: string@plugins, version?: string@versions]
	export extern "asdf update" []
	export extern "asdf current" [plugin?: string@plugins]
	export def "asdf plugin list" [] { [{name: nodejs, url: "native-url"}] }
}
export use native *
NU
	;;
"plugin list")
	[[ "${ASDF_NU_FAILURE:-}" != query ]] || exit 9
	printf 'nodejs\npython\n'
	;;
"list all nodejs") printf '22.0.0\n24.0.0\n' ;;
*) printf '%s\n' "$*" >>"$ASDF_NU_TEST_ROOT/native.log" ;;
esac
EOF
chmod +x "$test_root/bin/asdf"
bash "$repo_dir/libexec/asdf-extras" completion nushell >"$test_root/standalone.nu"
bash "$repo_dir/libexec/asdf-extras" completion --asdf nushell >"$test_root/combined.nu"
bash "$repo_dir/libexec/asdf-extras" init nushell >"$test_root/init.nu"
# What the initialized wrapper generates for `asdf completion nushell`.
bash "$repo_dir/libexec/asdf-extras" completion --asdf --wrappers nushell >"$test_root/wrapped.nu"
if grep -q 'ASDF_EXTRAS_COMPLETION_ORIGIN\|nushell-completion' "$test_root/init.nu"; then
	printf 'FAIL: init emitted completion\n' >&2
	exit 1
fi
cat >"$test_root/test.nu" <<'EOF'
source standalone.nu
source standalone.nu
def check [line: string, candidate: string] {
	let result = ($line | commandline complete)
	if $candidate not-in $result {
		error make {msg: $"missing ($candidate) for ($line): ($result | to nuon)"}
	}
}
check "asdf-extras up" update
check "asdf-extras completion --asdf n" nushell
check "asdf-extras install --local n" nodejs
check "asdf-extras update nodejs --version 24" "24.0.0"
check 'asdf-extras update "nodejs" ' "24.0.0"
check "asdf-extras update 'nodejs' " "24.0.0"
check 'asdf-extras update `nodejs` ' "24.0.0"
check 'asdf-extras install "no' nodejs
check "asdf-extras install 'no" nodejs
check 'asdf-extras install `no' nodejs
if (asdf-extras-argument-value '"line\nbreak"') != ("line" + (char newline) + "break") {
	error make {msg: "double-quoted escapes were not decoded"}
}
if (asdf-extras-argument-value '($env.SECRET)') != '($env.SECRET)' {
	error make {msg: "expression token was evaluated"}
}
source combined.nu
source combined.nu
check "asdf n" native-marker
check "asdf current n" nodejs
check "asdf install --local n" nodejs
check "asdf install nodejs --parent 22" "22.0.0"
check "asdf update --version nodejs --local 24" "24.0.0"
check "asdf update --all --" "--local"
check 'asdf update "nodejs" ' "24.0.0"
check 'asdf install "nodejs" --parent 22' "22.0.0"
check 'asdf completion "elvish" --' "--asdf"
check 'asdf completion "nushell" --' "--asdf"
let record = (asdf plugin list | first)
if $record.url != native-url { error make {msg: "structured native command lost"} }
asdf install --local nodejs 22.0.0
if (open --raw ($env.ASDF_NU_TEST_ROOT | path join native.log) | str trim) != "install --local nodejs 22.0.0" {
	error make {msg: "combined completion installed command wrappers"}
}
source init.nu
source init.nu
source wrapped.nu
source wrapped.nu
check "asdf n" native-marker
check "asdf install nodejs --local 22" "22.0.0"
check "asdf update --" "--version"
if (asdf plugin list | first).url != native-url { error make {msg: "initialized structured command lost"} }
asdf install --local nodejs 22.0.0
asdf update --version nodejs
asdf completion nushell
asdf completion elvish
let calls = (open --raw ($env.ASDF_NU_TEST_ROOT | path join dispatch.log) | lines)
if $calls != ["install --local nodejs 22.0.0" "update --version nodejs" "completion --asdf --wrappers nushell" "completion --asdf --wrappers elvish"] {
	error make {msg: $"incorrect wrapper routing: ($calls | to nuon)"}
}
$env.ASDF_NU_FAILURE = "query"
try {
	asdf-extras-candidates {command: [asdf-extras update ""]}
	error make {msg: "query failure suppressed"}
} catch {|err|
	if $err.msg !~ "completion failed" { error make $err }
}
print "Nushell completion tests: PASS"
EOF
nu --no-config-file -c "source '$test_root/standalone.nu'; if (scope commands | where name == asdf | length) != 0 { error make {msg: 'standalone installed asdf definitions'} }"
nu --no-config-file "$test_root/test.nu"
# Completion generated by the plugin entry point queries through `asdf cmd`.
bash "$repo_dir/lib/commands/command-completion" nushell >"$test_root/plugin.nu"
nu --no-config-file -c "source '$test_root/plugin.nu'; if update not-in ('asdf-extras up' | commandline complete) { error make {msg: 'plugin entry query failed'} }"
# Completion and wrappers keep working after the runtime that generated them is removed.
removed_runtime="$test_root/removed-runtime"
mkdir -p "$removed_runtime"
cp -R "$repo_dir/lib" "$repo_dir/libexec" "$removed_runtime/"
bash "$removed_runtime/libexec/asdf-extras" init nushell >"$test_root/removed-init.nu"
bash "$removed_runtime/libexec/asdf-extras" completion --asdf --wrappers nushell >"$test_root/removed-completion.nu"
: >"$test_root/dispatch.log"
nu --no-config-file -c "
	source '$test_root/removed-init.nu'
	source '$test_root/removed-completion.nu'
	^true
	rm -rf '$removed_runtime'
	if update not-in ('asdf-extras up' | commandline complete) { error make {msg: 'completion used a removed runtime'} }
	asdf update --version nodejs
"
[[ "$(<"$test_root/dispatch.log")" == 'update --version nodejs' ]] || {
	printf 'FAIL: wrapper did not reach the selected runtime\n' >&2
	exit 1
}
[[ ! -e "$removed_runtime" ]]
export ASDF_NU_QUERY_FAILURE=yes
for line in "asdf-extras update " "asdf update " "asdf completion "; do
	export ASDF_NU_COMPLETION_LINE="$line"
	nu --no-config-file -c "
		source '$test_root/init.nu'
		source '$test_root/wrapped.nu'
		\$env.ASDF_NU_COMPLETION_LINE | commandline complete | to nuon
	" >"$test_root/completion-output" 2>"$test_root/completion-error"
	if ! grep -q 'asdf-extras: completion failed: candidate-query-failed' "$test_root/completion-error"; then
		printf 'FAIL: completion engine hid query diagnostic: %s\n' "$line" >&2
		exit 1
	fi
done
for failure in generator empty; do
	if ASDF_NU_FAILURE="$failure" bash "$repo_dir/libexec/asdf-extras" completion --asdf nushell >"$test_root/output" 2>"$test_root/error"; then
		printf 'FAIL: native completion failure suppressed: %s\n' "$failure" >&2
		exit 1
	fi
	[[ ! -s "$test_root/output" && -s "$test_root/error" ]]
done

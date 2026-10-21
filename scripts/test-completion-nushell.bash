#!/usr/bin/env bash

set -euo pipefail

if ! command -v nu >/dev/null; then
	printf 'SKIP: Nushell is unavailable (requires 0.116.1 or newer)\n'
	exit 0
fi
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export ASDF_NU_TEST_ROOT="$test_root"
export PATH="$test_root/bin:$PATH"
mkdir -p "$test_root/bin"
cat >"$test_root/bin/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
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
bash "$repo_dir/lib/commands/command-completion" nushell >"$test_root/standalone.nu"
bash "$repo_dir/lib/commands/command-completion" --asdf nushell >"$test_root/combined.nu"
bash "$repo_dir/lib/commands/command-init" nushell >"$test_root/init.nu"
cat >"$test_root/dispatch.bash" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ASDF_NU_TEST_ROOT/dispatch.log"
EOF
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
source combined.nu
source combined.nu
check "asdf n" native-marker
check "asdf current n" nodejs
check "asdf install --local n" nodejs
check "asdf install nodejs --parent 22" "22.0.0"
check "asdf update --version nodejs --local 24" "24.0.0"
check "asdf update --all --" "--local"
let record = (asdf plugin list | first)
if $record.url != native-url { error make {msg: "structured native command lost"} }
asdf install --local nodejs 22.0.0
if (open --raw ($env.ASDF_NU_TEST_ROOT | path join native.log) | str trim) != "install --local nodejs 22.0.0" {
	error make {msg: "combined completion installed command wrappers"}
}
source init.nu
source init.nu
$env.ASDF_EXTRAS_DISPATCHER = ($env.ASDF_NU_TEST_ROOT | path join dispatch.bash)
check "asdf n" native-marker
check "asdf install nodejs --local 22" "22.0.0"
check "asdf update --" "--version"
if (asdf plugin list | first).url != native-url { error make {msg: "initialized structured command lost"} }
asdf install --local nodejs 22.0.0
asdf update --version nodejs
asdf completion nushell
asdf completion elvish
let calls = (open --raw ($env.ASDF_NU_TEST_ROOT | path join dispatch.log) | lines)
if $calls != ["install --local nodejs 22.0.0" "update --version nodejs" "completion --asdf nushell" "completion elvish"] {
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
for failure in generator empty; do
	if ASDF_NU_FAILURE="$failure" bash "$repo_dir/lib/commands/command-completion" --asdf nushell >"$test_root/output" 2>"$test_root/error"; then
		printf 'FAIL: native completion failure suppressed: %s\n' "$failure" >&2
		exit 1
	fi
	[[ ! -s "$test_root/output" && -s "$test_root/error" ]]
done

#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export ASDF_PRUNE_TEST_DIR="$test_dir"
export HOME="$test_dir/home"
export PATH="$test_dir/bin:$PATH"
mkdir -p "$HOME" "$test_dir/bin"
cat >"$test_dir/bin/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
plugin)
	if [[ "$2" == list ]]; then
		[[ "${ASDF_PRUNE_PLUGIN_LIST_FAIL:-0}" != 1 ]] || exit 1
		printf 'alpha\nbeta\norphan\n'
	fi
	;;
list)
	case "$2" in
	alpha)
		[[ "${ASDF_PRUNE_LIST_FAIL:-}" != alpha ]] || exit 1
		printf '* 1.0\n  2.0\n  3.0\n'
		;;
	beta) printf 'No versions installed\n' ;;
	orphan)
		[[ "${ASDF_PRUNE_LIST_FAIL:-}" != orphan ]] || exit 1
		printf ' 4.0\n 5.0\n'
		;;
	*) exit 1 ;;
	esac
	;;
uninstall)
	printf '%s %s\n' "$2" "$3" >>"$ASDF_PRUNE_TEST_DIR/uninstall.log"
	if [[ "${ASDF_PRUNE_UNINSTALL_FAIL:-}" == "$2:$3" ]]; then
		exit 1
	fi
	;;
*) exit 1 ;;
esac
EOF
chmod +x "$test_dir/bin/asdf"
printf 'alpha 1.0 2.0 # keep both fallback versions\nbeta system\n' >"$HOME/.tool-versions"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

dispatch="$repo_dir/lib/commands/dispatch.bash"
output="$(bash "$dispatch" prune)"
expected="$(printf 'alpha 3.0\norphan 4.0\norphan 5.0')"
[[ "$(<"$test_dir/uninstall.log")" == "$expected" ]] || fail "unexpected uninstall set: $(<"$test_dir/uninstall.log")"
[[ "$output" == *"removing unused version: alpha 3.0"* ]] || fail "unused alpha version not reported"
[[ "$output" == *"removing unused version: orphan 4.0"* ]] || fail "home-unlisted plugin version not pruned"
[[ "$output" == *"removing unused version: orphan 5.0"* ]] || fail "all versions of home-unlisted plugin not pruned"

if bash "$dispatch" prune extra >"$test_dir/output" 2>"$test_dir/error"; then
	fail 'unexpected positional argument accepted'
fi
grep -q 'usage: asdf-extras prune' "$test_dir/error" || fail 'invalid usage not reported'

if bash "$dispatch" prune --help >"$test_dir/output"; then
	grep -q 'All versions configured' "$test_dir/output" || fail 'prune help missing fallback version behavior'
else
	fail 'prune help failed'
fi
bash "$dispatch" help prune >"$test_dir/topic-help"
cmp "$test_dir/output" "$test_dir/topic-help" || fail 'prune help forms differ'

mv "$HOME/.tool-versions" "$test_dir/tool-versions.saved"
: >"$test_dir/uninstall.log"
if bash "$dispatch" prune >"$test_dir/output" 2>"$test_dir/error"; then
	fail 'missing home configuration accepted'
fi
grep -q 'home configuration does not exist' "$test_dir/error" || fail 'missing configuration error not reported'
[[ ! -s "$test_dir/uninstall.log" ]] || fail 'versions removed without a home configuration'
mv "$test_dir/tool-versions.saved" "$HOME/.tool-versions"

: >"$test_dir/uninstall.log"
if ASDF_PRUNE_PLUGIN_LIST_FAIL=1 bash "$dispatch" prune >"$test_dir/output" 2>"$test_dir/error"; then
	fail 'plugin-list failure accepted'
fi
grep -q 'could not list plugins' "$test_dir/error" || fail 'plugin-list failure not reported'
[[ ! -s "$test_dir/uninstall.log" ]] || fail 'versions removed after plugin-list failure'

: >"$test_dir/uninstall.log"
if ASDF_PRUNE_LIST_FAIL=alpha bash "$dispatch" prune >"$test_dir/output" 2>"$test_dir/error"; then
	fail 'version-list failure accepted'
fi
grep -q 'could not list installed versions for plugin: alpha' "$test_dir/error" ||
	fail 'version-list failure not reported'
grep -Fx 'orphan 4.0' "$test_dir/uninstall.log" >/dev/null || fail 'pruning did not continue after list failure'

: >"$test_dir/uninstall.log"
if ASDF_PRUNE_UNINSTALL_FAIL=alpha:3.0 bash "$dispatch" prune >"$test_dir/output" 2>"$test_dir/error"; then
	fail 'uninstall failure status not propagated'
fi
grep -q 'failed to remove version: alpha 3.0' "$test_dir/error" || fail 'uninstall failure not reported'
grep -Fx 'orphan 4.0' "$test_dir/uninstall.log" >/dev/null || fail 'pruning did not continue after uninstall failure'

printf 'prune regression tests: PASS\n'

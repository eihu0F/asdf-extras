#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export ASDF_TEST_LOG="${test_dir}/asdf.log"
export ASDF_EXTRAS_INSTALL_ENV_DIR="${test_dir}/env"
export PATH="${test_dir}:$PATH"

cat >"${test_dir}/asdf" <<'EOF'
#!/bin/sh
printf '<%s>' "$@" >>"$ASDF_TEST_LOG"
printf '\n' >>"$ASDF_TEST_LOG"
EOF
chmod +x "${test_dir}/asdf"

fail() {
	printf "FAIL: %s\n" "$*" >&2
	exit 1
}

assert_install() {
	local scope="$1"
	local options="$2"
	local actual expected
	shift 2

	: >"$ASDF_TEST_LOG"
	"$BASH" "${repo_dir}/lib/commands/command-install" "$@"
	actual="$(<"$ASDF_TEST_LOG")"
	expected="$(printf '<install>%s\n<set>%s' "$options" "$scope")"
	[[ "$actual" == "$expected" ]] || fail "unexpected asdf arguments: $actual"
}

assert_invalid() {
	local expected="$1"
	local output
	shift

	: >"$ASDF_TEST_LOG"
	if output="$("$BASH" "${repo_dir}/lib/commands/command-install" "$@" 2>&1)"; then
		fail "invalid arguments were accepted: $*"
	fi
	[[ "$output" == "asdf-extras: $expected" ]] || fail "unexpected error: $output"
	[[ ! -s "$ASDF_TEST_LOG" ]] || fail "asdf was called for invalid arguments"
}

printf 'Testing install with Bash %s\n' "$BASH_VERSION"

assert_install '<--home><asdf-extras><latest>' '<asdf-extras><latest>' asdf-extras latest
for scope in -u --home; do
	assert_install '<--home><nodejs><24.11.0>' '<nodejs><24.11.0>' "$scope" nodejs 24.11.0
done
for scope in -p --parent; do
	assert_install '<--parent><nodejs><24.11.0>' '<nodejs><24.11.0>' nodejs "$scope" 24.11.0
done
assert_install '<--home><nodejs><24.11.0>' '<--verbose><--custom=value with spaces><nodejs><24.11.0>' \
	--verbose nodejs '--custom=value with spaces' 24.11.0
assert_install '<--parent><plugin with spaces><version with spaces>' \
	'<--verbose><plugin with spaces><version with spaces>' \
	--verbose --parent 'plugin with spaces' 'version with spaces'

usage="usage: asdf-extras install [options] <plugin> <version>"
assert_invalid "$usage"
assert_invalid "$usage" --home
assert_invalid "$usage" --verbose
assert_invalid "$usage" nodejs
assert_invalid "$usage" --parent nodejs
assert_invalid "-u/--home and -p/--parent cannot be used together" --home --parent nodejs 24.11.0

printf 'install regression tests: PASS\n'

#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export HOME="$test_root/home"
mkdir -p "$HOME" "$test_root/project/child"
cd "$test_root/project/child"
unset ASDF_DEFAULT_TOOL_VERSIONS_FILENAME ASDF_PYTHON_VERSION ASDF_NODEJS_VERSION

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

# Both entry points must behave the same.
run_get() {
	local installed plugin
	installed="$("$BASH" "${repo_dir}/libexec/asdf-extras" get "$@" 2>&1)" && rc=0 || rc=$?
	plugin="$("$BASH" "${repo_dir}/lib/commands/command-get" "$@" 2>&1)" && plugin_rc=0 || plugin_rc=$?
	[[ "$installed" == "$plugin" && "$rc" == "$plugin_rc" ]] || fail "entry points differ for get $*: <$installed> <$plugin>"
	output="$installed"
}

expect() {
	local expected="$1" expected_rc="$2"
	shift 2
	run_get "$@"
	[[ "$output" == "$expected" ]] || fail "get $*: expected <$expected>, got <$output>"
	[[ "$rc" == "$expected_rc" ]] || fail "get $*: expected status $expected_rc, got $rc"
}

printf 'python 3.12.0 3.11.0 system # fallbacks\nnodejs 22.1.0\n# comment\n' >"$HOME/.tool-versions"
printf 'python 3.10.0\nruby 3.3.0\n' >"$test_root/project/.tool-versions"
printf 'python 3.9.0\n' >.tool-versions
snapshot="$(cat "$HOME/.tool-versions" "$test_root/project/.tool-versions" .tool-versions)"

# Home is the default scope; order and fallbacks are kept as one line.
expect '3.12.0 3.11.0 system' 0 python
expect '3.12.0 3.11.0 system' 0 --home python
expect '3.12.0 3.11.0 system' 0 -u python
expect '22.1.0' 0 nodejs --home
# Parent skips the current directory's file; local reads only that file.
expect '3.10.0' 0 -p python
expect '3.10.0' 0 --parent python
expect '3.9.0' 0 --local python
# Entries are read from the selected file only, never from another one.
expect 'asdf-extras: no version configured for nodejs in '"$PWD/.tool-versions" 2 --local nodejs
expect 'asdf-extras: no version configured for ruby in '"$HOME/.tool-versions" 2 ruby
expect '3.3.0' 0 --parent ruby
# Without a plugin every entry is listed, like asdf current does.
expect "$(printf 'python 3.12.0 3.11.0 system\nnodejs 22.1.0')" 0
expect "$(printf 'python 3.10.0\nruby 3.3.0')" 0 --parent
expect 'python 3.9.0' 0 --local
# Version overrides in the environment are ignored.
ASDF_PYTHON_VERSION=9.9.9 run_get python
[[ "$output" == '3.12.0 3.11.0 system' ]] || fail "environment override was read: $output"
# Reading does not require the versions to be installed (no asdf is needed here).
PATH="$(dirname "$BASH"):/usr/bin:/bin" run_get python
[[ "$output" == '3.12.0 3.11.0 system' ]] || fail "get needed asdf: $output"

# A custom configuration file name is honored.
export ASDF_DEFAULT_TOOL_VERSIONS_FILENAME=.versions
printf 'python 1.0\n' >"$HOME/.versions"
expect '1.0' 0 python
expect 'asdf-extras: no version configured for nodejs in '"$HOME/.versions" 2 nodejs
unset ASDF_DEFAULT_TOOL_VERSIONS_FILENAME

# Missing files: nothing is listed for home/local, and nothing is created.
rm .tool-versions
expect '' 0 --local
expect 'asdf-extras: no version configured for python in '"$PWD/.tool-versions" 2 --local python
[[ ! -e .tool-versions ]] || fail "get created a configuration file"
rm "$test_root/project/.tool-versions" "$HOME/.tool-versions"
expect 'asdf-extras: no .tool-versions found in a parent directory' 1 --parent python
expect 'asdf-extras: no .tool-versions found in a parent directory' 1 --parent
expect '' 0
[[ ! -e "$HOME/.tool-versions" ]] || fail "get created the home configuration file"

# Invalid arguments fail with status 1.
expect 'asdf-extras: --home, --parent and --local cannot be used together' 1 --home --local python
expect 'asdf-extras: --home, --parent and --local cannot be used together' 1 -u -p
expect 'asdf-extras: unknown get option: --bogus' 1 --bogus python
expect 'asdf-extras: usage: asdf-extras get [--home|-u|--parent|-p|--local] [<plugin>]' 1 python nodejs

# Reading never changed the files that existed at the start.
printf 'python 3.12.0 3.11.0 system # fallbacks\nnodejs 22.1.0\n# comment\n' >"$HOME/.tool-versions"
printf 'python 3.10.0\nruby 3.3.0\n' >"$test_root/project/.tool-versions"
printf 'python 3.9.0\n' >.tool-versions
run_get python
[[ "$(cat "$HOME/.tool-versions" "$test_root/project/.tool-versions" .tool-versions)" == "$snapshot" ]] || fail "get changed a configuration file"

# Help is available from both entry points.
"$BASH" "$repo_dir/libexec/asdf-extras" get --help | grep -q 'Read-only' || fail "get --help"
"$BASH" "$repo_dir/libexec/asdf-extras" help get | grep -q 'Read-only' || fail "help get"
"$BASH" "$repo_dir/lib/commands/command-get" -h | grep -q 'Read-only' || fail "plugin get -h"

printf 'get regression tests: PASS\n'

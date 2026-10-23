#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
native_asdf="$(command -v asdf || true)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export ASDF_TEST_LOG="${test_dir}/asdf.log"
export ASDF_TEST_ENV_LOG="${test_dir}/asdf.env.log"
export ASDF_EXTRAS_INSTALL_ENV_DIR="${test_dir}/env"
unset ASDF_EXTRAS_INSTALL_ENV_FUNCTION ASDF_EXTRAS_INSTALL_ENV_FUNCTION_NODEJS \
	ASDF_EXTRAS_INSTALL_ENV_FUNCTION_PYTHON ASDF_EXTRAS_INSTALL_ENV_FILE_NODEJS \
	ASDF_EXTRAS_INSTALL_ENV_FILE_PYTHON
export PATH="${test_dir}:$PATH"
export HOME="${test_dir}/home"
mkdir -p "$HOME" "${test_dir}/project/child"
cd "${test_dir}/project/child"
printf '# parent configuration\n' >../.tool-versions

cat >"${test_dir}/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
latest) printf '9.0\n' ;;
list) cat "${ASDF_TEST_LOG}.installed" ;;
install)
	printf '<%s>' "$@" >>"$ASDF_TEST_LOG"
	printf '\n' >>"$ASDF_TEST_LOG"
	printf '<install><%s><%s><%s>\n' "$2" "$3" "${ASDF_TEST_MARKER-}" >>"$ASDF_TEST_ENV_LOG"
	for version in "$@"; do :; done
	printf '%s\n' "$version" >"${ASDF_TEST_LOG}.installed"
	;;
set)
	printf '<%s>' "$@" >>"$ASDF_TEST_LOG"
	printf '\n' >>"$ASDF_TEST_LOG"
	set_plugin="$2"
	if [[ "$set_plugin" == --* ]]; then
		set_plugin="$3"
	fi
	printf '<set><%s><%s>\n' "$set_plugin" "${ASDF_TEST_MARKER-}" >>"$ASDF_TEST_ENV_LOG"
	if [[ -n "${ASDF_TEST_NATIVE_ASDF:-}" ]]; then
		exec "$ASDF_TEST_NATIVE_ASDF" "$@"
	fi
	shift
	file="$PWD/.tool-versions"
	case "$1" in
	--home) file="$HOME/.tool-versions"; shift ;;
	--parent) file="$PWD/../.tool-versions"; shift ;;
	esac
	printf '%s %s\n' "$1" "$2" >"$file"
	;;
esac
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
	printf '# reset\n' >"$HOME/.tool-versions"
	printf '# reset\n' >../.tool-versions
	printf '# reset\n' >.tool-versions
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

assert_install '<--home><asdf-extras><9.0>' '<asdf-extras><9.0>' asdf-extras latest
assert_install '<nodejs><9.0>' '<nodejs><9.0>' nodejs latest:9 --local
for scope in -u --home; do
	assert_install '<--home><nodejs><24.11.0>' '<nodejs><24.11.0>' "$scope" nodejs 24.11.0
done
assert_install '<nodejs><24.11.0>' '<nodejs><24.11.0>' --local nodejs 24.11.0
for scope in -p --parent; do
	assert_install '<--parent><nodejs><24.11.0>' '<nodejs><24.11.0>' nodejs "$scope" 24.11.0
done
assert_install '<--home><nodejs><24.11.0>' '<--verbose><--custom=value with spaces><nodejs><24.11.0>' \
	--verbose nodejs '--custom=value with spaces' 24.11.0
assert_install '<--parent><nodejs><24.11.0>' \
	'<--custom=value with spaces><nodejs><24.11.0>' \
	'--custom=value with spaces' --parent nodejs 24.11.0

usage="usage: asdf-extras install [options] <plugin> <version>"
assert_invalid "$usage"
assert_invalid "$usage" --home
assert_invalid "$usage" --verbose
assert_invalid "$usage" nodejs
assert_invalid "$usage" --parent nodejs
assert_invalid "--home, --parent and --local cannot be used together" --home --parent nodejs 24.11.0
assert_invalid "--home, --parent and --local cannot be used together" --local --parent nodejs 24.11.0

rm ../.tool-versions
assert_invalid "no .tool-versions found in a parent directory" --parent nodejs 24.11.0

mkdir -p "$ASDF_EXTRAS_INSTALL_ENV_DIR"
cat >"${ASDF_EXTRAS_INSTALL_ENV_DIR}/nodejs.env" <<'EOF'
export ASDF_TEST_MARKER=nodejs-env
EOF
cat >"${ASDF_EXTRAS_INSTALL_ENV_DIR}/python.env" <<'EOF'
export ASDF_TEST_MARKER=python-env
EOF
: >"$ASDF_TEST_ENV_LOG"
"$BASH" "${repo_dir}/lib/commands/command-install" nodejs 1.2.3
"$BASH" "${repo_dir}/lib/commands/command-install" python 3.4.5
grep -Fx '<install><nodejs><1.2.3><nodejs-env>' "$ASDF_TEST_ENV_LOG" >/dev/null ||
	fail "nodejs install env was not applied to install"
grep -Fx '<set><nodejs><>' "$ASDF_TEST_ENV_LOG" >/dev/null ||
	fail "nodejs install env leaked into set"
grep -Fx '<install><python><3.4.5><python-env>' "$ASDF_TEST_ENV_LOG" >/dev/null ||
	fail "python install env was not applied to install"
grep -Fx '<set><python><>' "$ASDF_TEST_ENV_LOG" >/dev/null ||
	fail "python install env leaked into set"

# Check shell wrappers route local installs while leaving plain installs native.
for shell_name in bash zsh fish; do
	if ! command -v "$shell_name" >/dev/null; then
		continue
	fi
	: >"$ASDF_TEST_LOG"
	printf '# reset\n' >.tool-versions
	if [[ "$shell_name" == fish ]]; then
		# shellcheck disable=SC2016
		"$shell_name" -c 'source "$argv[1]/lib/init/fish.fish"; asdf install --local nodejs 8.0' -- "$repo_dir"
	else
		# shellcheck disable=SC2016
		"$shell_name" -c 'ASDF_EXTRAS_DISPATCHER="$1/lib/commands/dispatch.bash"; source "$1/lib/init/$2"; asdf install --local nodejs 8.0' \
			-- "$repo_dir" "$([[ "$shell_name" == bash ]] && printf bash.sh || printf zsh.zsh)"
	fi
	grep -Fx '<set><nodejs><8.0>' "$ASDF_TEST_LOG" >/dev/null || fail "$shell_name: local install not routed"
done

if [[ -n "$native_asdf" ]]; then
	export ASDF_TEST_NATIVE_ASDF="$native_asdf"
	printf 'nodejs 1.0\n' >../.tool-versions
	printf 'nodejs 3.0\n' >.tool-versions
	"$BASH" "${repo_dir}/lib/commands/command-install" --parent nodejs 4.0
	grep -Fx 'nodejs 4.0' ../.tool-versions >/dev/null || fail "native parent scope was not updated"
	grep -Fx 'nodejs 3.0' .tool-versions >/dev/null || fail "native parent changed local scope"
	rm .tool-versions
	"$BASH" "${repo_dir}/lib/commands/command-install" --local nodejs 5.0
	grep -Fx 'nodejs 5.0' .tool-versions >/dev/null || fail "native local scope was not created"
	"$BASH" "${repo_dir}/lib/commands/command-install" --home nodejs 6.0
	grep -Fx 'nodejs 6.0' "$HOME/.tool-versions" >/dev/null || fail "native home scope was not updated"
fi

printf 'install regression tests: PASS\n'

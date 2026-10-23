#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
jq_bin="$(command -v jq)"
if [[ "$jq_bin" == */shims/jq ]]; then
	jq_bin="$(asdf which jq)"
fi
test_dir="$(mktemp -d)"
test_dir="$(cd "$test_dir" && pwd -P)"
trap 'rm -rf "$test_dir"' EXIT
export HOME="$test_dir/home"
export ASDF_DATA_DIR="$test_dir/data"
export ASDF_SELF_TEST_DIR="$test_dir"
mkdir -p "$HOME/bin" "$test_dir/mocks"
ln -s "$jq_bin" "$test_dir/mocks/jq"
export PATH="$test_dir/mocks:$HOME/bin:$PATH"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

cat >"$test_dir/mocks/uname" <<'EOF'
#!/bin/sh
case "$1" in
-s) printf '%s\n' "${ASDF_SELF_TEST_OS:-Linux}" ;;
-m) printf '%s\n' "${ASDF_SELF_TEST_ARCH:-x86_64}" ;;
esac
EOF
# Model native executable headers while using shell scripts as test binaries.
cat >"$test_dir/mocks/od" <<'EOF'
#!/bin/sh
printf '%s\n' "${ASDF_SELF_TEST_MAGIC:-7f 45 4c 46}"
EOF
cat >"$test_dir/mocks/brew" <<'EOF'
#!/bin/sh
case "$1" in
--cellar) printf '%s/cellar/asdf\n' "$ASDF_SELF_TEST_DIR" ;;
upgrade) printf 'brew upgrade asdf\n' >>"$ASDF_SELF_TEST_DIR/log"; exit "${ASDF_SELF_TEST_BREW_STATUS:-0}" ;;
esac
EOF
cat >"$test_dir/mocks/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl\n' >>"$ASDF_SELF_TEST_DIR/log"
[[ "${ASDF_SELF_TEST_NETWORK_FAIL:-0}" == 0 ]] || exit 22
for arg in "$@"; do
	if [[ "$arg" == https://api.github.com/* ]]; then
		source_file="$ASDF_SELF_TEST_DIR/release.json"
	fi
done
source_file="${source_file:-$ASDF_SELF_TEST_DIR/release.tar.gz}"
while [[ $# -gt 0 ]]; do
	if [[ "$1" == -o ]]; then
		cp "$source_file" "$2"
		exit
	fi
	shift
done
exit 1
EOF
chmod +x "$test_dir/mocks/uname" "$test_dir/mocks/od" "$test_dir/mocks/brew" "$test_dir/mocks/curl"

reset_binary() {
	printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "${1:-v0.20.1}" >"$HOME/bin/asdf"
	chmod +x "$HOME/bin/asdf"
	: >"$test_dir/log"
}

make_release() {
	local version="$1" digest
	mkdir -p "$test_dir/archive"
	printf '#!/bin/sh\nprintf "%s\\n"\n' "$version" >"$test_dir/archive/asdf"
	tar -czf "$test_dir/release.tar.gz" -C "$test_dir/archive" asdf
	if command -v sha256sum >/dev/null 2>&1; then
		digest="$(sha256sum "$test_dir/release.tar.gz")"
	else
		digest="$(shasum -a 256 "$test_dir/release.tar.gz")"
	fi
	printf '{"tag_name":"v0.20.2","assets":[{"name":"asdf-v0.20.2-%s.tar.gz","digest":"sha256:%s"}]}\n' \
		"${ASDF_SELF_TEST_ASSET:-linux-amd64}" "${digest%% *}" >"$test_dir/release.json"
}

assert_failure_preserves_binary() {
	local output previous
	previous="$("$HOME/bin/asdf" --version)"
	if output="$("$BASH" "$repo_dir/lib/extras/update-asdf.bash" 2>&1)"; then
		fail "expected update failure"
	fi
	[[ -n "$output" ]] || fail "failure did not report an error"
	[[ "$("$HOME/bin/asdf" --version)" == "$previous" ]] || fail "failure replaced the existing asdf"
	[[ -z "$(find "$HOME/bin" -name '.asdf-update.*' -print)" ]] || fail "staging files leaked"
}

printf 'Testing asdf self-update with Bash %s\n' "$BASH_VERSION"
reset_binary
make_release v0.20.2
"$BASH" "$repo_dir/lib/extras/update-asdf.bash"
[[ "$("$HOME/bin/asdf" --version)" == v0.20.2 ]] || fail "new binary not activated"
: >"$test_dir/log"
"$BASH" "$repo_dir/lib/extras/update-asdf.bash"
[[ "$(wc -l <"$test_dir/log" | tr -d ' ')" == 1 ]] || fail "already-current release was downloaded"

for format in 'v0.20.1' '0.20.1' 'asdf version v0.20.1 (revision old)' 'asdf version 0.20.1'; do
	reset_binary "$format"
	make_release 'asdf version v0.20.2 (revision cb72590)'
	"$BASH" "$repo_dir/lib/extras/update-asdf.bash"
	[[ "$("$HOME/bin/asdf" --version)" == 'asdf version v0.20.2 (revision cb72590)' ]] ||
		fail "prefixed release was not activated"
	: >"$test_dir/log"
	"$BASH" "$repo_dir/lib/extras/update-asdf.bash"
	[[ "$(wc -l <"$test_dir/log" | tr -d ' ')" == 1 ]] || fail "prefixed current version was downloaded again"
done
for format in '0.20.2' 'asdf version 0.20.2' 'v0.20.2 (revision test)'; do
	reset_binary 'asdf version v0.20.1 (revision old)'
	make_release "$format"
	"$BASH" "$repo_dir/lib/extras/update-asdf.bash"
	[[ "$("$HOME/bin/asdf" --version)" == "$format" ]] || fail "release format rejected: $format"
done
for invalid in 'unknown' 'asdf version v0.20' 'v0.20.20' 'v0.20.2-rc1' 'asdf version v0.99.0'; do
	reset_binary 'asdf version v0.20.1 (revision old)'
	make_release "$invalid"
	assert_failure_preserves_binary
done
for invalid in 'unknown' 'asdf version v0.20' 'v0.20.1-rc1'; do
	reset_binary "$invalid"
	make_release v0.20.2
	assert_failure_preserves_binary
done
reset_binary 'asdf version v0.21.0 (revision newer)'
make_release v0.20.2
"$BASH" "$repo_dir/lib/extras/update-asdf.bash"
[[ "$(wc -l <"$test_dir/log" | tr -d ' ')" == 1 ]] || fail "newer installed version was downgraded"

reset_binary
export ASDF_SELF_TEST_NETWORK_FAIL=1
assert_failure_preserves_binary
unset ASDF_SELF_TEST_NETWORK_FAIL
make_release v0.20.2
printf 'corrupted' >>"$test_dir/release.tar.gz"
assert_failure_preserves_binary
make_release v0.99.0
assert_failure_preserves_binary
printf '{"tag_name":"invalid"}\n' >"$test_dir/release.json"
assert_failure_preserves_binary
printf '{"tag_name":"v0.20.2","assets":[]}\n' >"$test_dir/release.json"
assert_failure_preserves_binary
export ASDF_SELF_TEST_MAGIC='23 21 2f 62'
assert_failure_preserves_binary
unset ASDF_SELF_TEST_MAGIC
cp "$HOME/bin/asdf" "$test_dir/mocks/asdf"
assert_failure_preserves_binary
[[ "$("$test_dir/mocks/asdf" --version)" == v0.20.1 ]] || fail "unsupported installation was modified"
rm "$test_dir/mocks/asdf"
export ASDF_SELF_TEST_OS=Unsupported
assert_failure_preserves_binary
unset ASDF_SELF_TEST_OS
export ASDF_SELF_TEST_ARCH=Unsupported
assert_failure_preserves_binary
unset ASDF_SELF_TEST_ARCH

for arch in arm64 x86_64; do
	reset_binary
	export ASDF_SELF_TEST_OS=Darwin ASDF_SELF_TEST_ARCH="$arch"
	if [[ "$arch" == arm64 ]]; then
		export ASDF_SELF_TEST_ASSET=darwin-arm64
	else
		export ASDF_SELF_TEST_ASSET=darwin-amd64
	fi
	make_release v0.20.2
	"$BASH" "$repo_dir/lib/extras/update-asdf.bash"
	[[ "$("$HOME/bin/asdf" --version)" == v0.20.2 ]] || fail "Darwin asset selection failed"
done
unset ASDF_SELF_TEST_OS ASDF_SELF_TEST_ARCH ASDF_SELF_TEST_ASSET

reset_binary
chmod a-w "$HOME/bin/asdf"
# Root bypasses permission checks; regular users must receive an explicit error.
if [[ ! -w "$HOME/bin/asdf" ]]; then
	assert_failure_preserves_binary
fi
chmod u+w "$HOME/bin/asdf"

mv "$HOME/bin/asdf" "$HOME/bin/original"
ln -s original "$HOME/bin/asdf"
assert_failure_preserves_binary
rm "$HOME/bin/asdf"
mkdir -p "$test_dir/cellar/asdf/0.20.1/bin"
mv "$HOME/bin/original" "$test_dir/cellar/asdf/0.20.1/bin/asdf"
ln -s "$test_dir/cellar/asdf/0.20.1/bin/asdf" "$HOME/bin/asdf"
"$BASH" "$repo_dir/lib/extras/update-asdf.bash"
grep -Fx 'brew upgrade asdf' "$test_dir/log" >/dev/null || fail "Homebrew was not detected"
export ASDF_SELF_TEST_BREW_STATUS=1
assert_failure_preserves_binary
unset ASDF_SELF_TEST_BREW_STATUS

mkdir -p "$ASDF_DATA_DIR/asdf-extras"
cat >"$ASDF_DATA_DIR/asdf-extras/update-asdf.bash" <<'EOF'
printf '%s\n' "$1" >"$ASDF_SELF_TEST_DIR/script-path"
exit "${ASDF_SELF_TEST_SCRIPT_STATUS:-0}"
EOF
"$BASH" "$repo_dir/lib/extras/update-asdf.bash"
[[ "$(<"$test_dir/script-path")" == "$HOME/bin/asdf" ]] || fail "custom script did not receive executable path"
export ASDF_SELF_TEST_SCRIPT_STATUS=1
assert_failure_preserves_binary
printf 'asdf self-update regression tests: PASS\n'

#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export ASDF_TEST_DIR="$test_dir"
export ASDF_TEST_REPO_DIR="$repo_dir"
unset ASDF_EXTRAS_PLUGIN_NAME ASDF_EXTRAS_ORIGIN
export HOME="${test_dir}/home"
export ASDF_EXTRAS_INSTALL_ENV_DIR="${test_dir}/env"
export ASDF_DATA_DIR="${test_dir}/data"
mkdir -p "$HOME" "${test_dir}/project/child"
mkdir -p "$ASDF_DATA_DIR/asdf-extras"
cat >"$ASDF_DATA_DIR/asdf-extras/update-asdf.bash" <<'EOF'
printf 'self-update\n' >>"$ASDF_TEST_DIR/log"
[[ "$ASDF_TEST_SCENARIO" != self-update-fails ]]
EOF
cd "${test_dir}/project/child"
export PATH="${test_dir}:$PATH"

cat >"${test_dir}/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
cmd | exec) printf '%s\n' "$*" >>"$ASDF_TEST_DIR/nested" ;;
*) printf '%s\n' "$*" >>"$ASDF_TEST_DIR/log" ;;
esac
case "$1" in
cmd)
	# Like asdf, reject options before -- and drop the first --.
	shift 2
	command_name="$1"
	command_args=()
	shift
	while [[ $# -gt 0 && "$1" != -- ]]; do
		if [[ "$1" == -* ]]; then
			printf 'Incorrect Usage: flag provided but not defined: %s\n' "$1" >&2
			exit 1
		fi
		command_args+=("$1")
		shift
	done
	[[ $# -eq 0 ]] || shift
	# The plugin checkout is the repository under test.
	exec "$BASH" "$ASDF_TEST_REPO_DIR/lib/commands/command-$command_name" ${command_args[@]+"${command_args[@]}"} "$@"
	;;
exec)
	# Resolve the selected extras version on every call, as asdf shims do.
	[[ "$2" == asdf-extras ]] || exit 1
	tool="${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}"
	selected=""
	directory="$PWD"
	while [[ -z "$selected" ]]; do
		if [[ -f "$directory/.tool-versions" ]]; then
			selected="$(awk -v tool="$tool" '$1 == tool { print $2; exit }' "$directory/.tool-versions")"
		fi
		[[ "$directory" != / ]] || break
		directory="$(dirname "$directory")"
	done
	if [[ -z "$selected" && -f "$HOME/.tool-versions" ]]; then
		selected="$(awk -v tool="$tool" '$1 == tool { print $2; exit }' "$HOME/.tool-versions")"
	fi
	case "$selected" in
	1.0) runtime="$ASDF_TEST_DIR/runtime-old" ;;
	*) runtime="$ASDF_TEST_DIR/runtime-$selected" ;;
	esac
	if [[ -z "$selected" || ! -f "$runtime/libexec/asdf-extras" ]]; then
		printf 'no installed extras runtime selected: %s\n' "$selected" >&2
		exit 126
	fi
	printf 'runtime %s\n' "$(basename "$runtime")" >>"$ASDF_TEST_DIR/nested"
	shift 2
	exec "$BASH" "$runtime/libexec/asdf-extras" "$@"
	;;
plugin)
	if [[ "$2" == update && "${3:-}" == test && "$ASDF_TEST_SCENARIO" == plugin-update-fails ]]; then
		exit 1
	fi
	if [[ "$2" == list ]]; then
		if [[ "${ASDF_TEST_RUNTIME_UPDATE:-0}" == 1 ]]; then
			printf '%s\ntest\nnext\n' "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}"
		else
			printf 'test\nnext\n'
		fi
	fi
	;;
latest)
	[[ "$ASDF_TEST_SCENARIO" != unresolved || "$2" != test ]] || exit 1
	printf '2.0\n'
	;;
current)
	printf 'Name Version Source\n%s %s home\n' "$2" "$(cat "$ASDF_TEST_DIR/$2-current")"
	;;
list)
	if [[ "$2" == all ]]; then
		printf '1.0\n2.0\n'
	else
		cat "$ASDF_TEST_DIR/$2-installed"
	fi
	;;
install)
	if [[ "$2" == "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" && "$ASDF_TEST_SCENARIO" == extras-install-fails ]]; then
		exit 1
	fi
	if [[ "${ASDF_TEST_RUNTIME_UPDATE:-0}" == 1 ]]; then
		[[ -r "$ASDF_TEST_DIR/runtime-old/lib/extras/dispatch.bash" ]] || {
			printf 'running extras runtime removed before install: %s\n' "$2" >&2
			exit 1
		}
		if [[ "$2" == "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" ]]; then
			mkdir -p "$ASDF_TEST_DIR/runtime-$3"
			cp -R "$ASDF_TEST_REPO_DIR/lib" "$ASDF_TEST_REPO_DIR/libexec" "$ASDF_TEST_DIR/runtime-$3/"
		fi
	fi
	if [[ "$2" == test ]]; then
		case "$ASDF_TEST_SCENARIO" in
		install-fails) exit 1 ;;
		partial-install-fails)
			printf '%s\n' "$3" >>"$ASDF_TEST_DIR/$2-installed"
			exit 1
			;;
		missing-install) exit 0 ;;
		esac
	fi
	printf '%s\n' "$3" >>"$ASDF_TEST_DIR/$2-installed"
	;;
set)
	scope=--local
	shift
	case "$1" in
	--home | --parent)
		scope="$1"
		shift
		;;
	esac
	plugin="$1"
	version="$2"
	if [[ "$plugin" == "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" && "$ASDF_TEST_SCENARIO" == extras-set-fails ]]; then
		exit 1
	fi
	if [[ "$plugin" == test ]]; then
		case "$ASDF_TEST_SCENARIO" in
		set-fails) exit 1 ;;
		set-ineffective) exit 0 ;;
		esac
	fi
	case "$scope" in
	--home) file="$HOME/.tool-versions" ;;
	--parent) file="$ASDF_TEST_DIR/project/.tool-versions" ;;
	--local) file="$PWD/.tool-versions" ;;
	esac
	: >"$file.tmp"
	if [[ -f "$file" ]]; then
		awk -v plugin="$plugin" '$1 != plugin' "$file" >"$file.tmp"
	fi
	printf '%s %s\n' "$plugin" "$version" >>"$file.tmp"
	mv "$file.tmp" "$file"
	printf '%s\n' "$version" >"$ASDF_TEST_DIR/$plugin-current"
	;;
uninstall)
	if [[ "$2" == "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" && "${ASDF_TEST_RUNTIME_UPDATE:-0}" == 1 ]]; then
		[[ "$ASDF_TEST_SCENARIO" != cleanup-fails ]] || exit 1
		rm -rf "$ASDF_TEST_DIR/runtime-old"
	fi
	printf '%s\n' "$3" >"$ASDF_TEST_DIR/$2-removed"
	;;
*) exit 1 ;;
esac
EOF
chmod +x "${test_dir}/asdf"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

run_case() {
	local scenario="$1"
	local mode="$2"
	local output rc plugin expected
	export ASDF_TEST_SCENARIO="$scenario"

	: >"${test_dir}/log"
	: >"${test_dir}/nested"
	printf 'test 1.0\nnext 1.0\n' >"$HOME/.tool-versions"
	for plugin in test next; do
		printf '1.0\n' >"${test_dir}/$plugin-current"
		printf '1.0\n' >"${test_dir}/$plugin-installed"
		: >"${test_dir}/$plugin-removed"
	done

	if [[ "$mode" == default ]]; then
		set --
	else
		set -- "$mode"
	fi
	if output="$("$BASH" "${repo_dir}/lib/commands/command-update" "$@" 2>&1)"; then
		rc=0
	else
		rc=$?
	fi

	if [[ "$scenario" == success ]]; then
		[[ $rc -eq 0 ]] || fail "$mode/$scenario: $output"
		[[ "$(<"${test_dir}/test-current")" == 2.0 ]] || fail "target was not activated"
		[[ "$(<"${test_dir}/test-removed")" == 1.0 ]] || fail "previous version was not removed"
		expected="$(printf 'install test 2.0\nset --home test 2.0\nuninstall test 1.0')"
		[[ "$(grep -E '^(install|set|uninstall) .*test ' "${test_dir}/log")" == "$expected" ]] ||
			fail "incorrect install/activation/removal order"
		if grep -q '^plugin update --all' "${test_dir}/log"; then
			fail "bulk plugin update used"
		fi
		# Plugin-mode installs stay in the plugin checkout; no extras CLI exists here.
		grep -Fx 'cmd asdf-extras install -- --home test latest' "${test_dir}/nested" >/dev/null ||
			fail "$mode: plugin-mode install did not use asdf cmd"
		if grep -q '^exec ' "${test_dir}/nested"; then
			fail "$mode: plugin-mode install used the installed CLI"
		fi
		if [[ "$mode" != test ]]; then
			[[ "$(grep -E '^(plugin update|install|set|uninstall) ' "${test_dir}/log")" == "$(printf 'plugin update test\ninstall test 2.0\nset --home test 2.0\nuninstall test 1.0\nplugin update next\ninstall next 2.0\nset --home next 2.0\nuninstall next 1.0')" ]] ||
				fail "plugin update/install operations were not interleaved"
		fi
	else
		[[ ! -s "${test_dir}/test-removed" ]] || fail "$mode/$scenario: previous version was removed"
		[[ "$(<"${test_dir}/test-current")" == 1.0 ]] || fail "$mode/$scenario: selection changed"
		[[ "$output" == *"asdf-extras:"* ]] || fail "$mode/$scenario: no error reported"
		case "$scenario" in
		plugin-update-fails | install-fails | partial-install-fails | missing-install | unresolved)
			if grep -q '^set --home test ' "${test_dir}/log"; then
				fail "$mode/$scenario: activation attempted after install failure"
			fi
			;;
		esac
		[[ $rc -ne 0 ]] || fail "$mode/$scenario: failure was not propagated"
		if [[ "$mode" != test ]]; then
			[[ "$(<"${test_dir}/next-current")" == 2.0 ]] || fail "$mode/$scenario: next plugin was not updated"
		fi
	fi
}

printf 'Testing update with Bash %s\n' "$BASH_VERSION"
for mode in test --all default; do
	for scenario in success plugin-update-fails install-fails partial-install-fails missing-install set-fails set-ineffective unresolved; do
		run_case "$scenario" "$mode"
	done

	export ASDF_TEST_SCENARIO=success
	for targets in '--plugin' '--version' '--plugin --version' '--asdf --plugin --version'; do
		printf 'test 1.0\n' >"$HOME/.tool-versions"
		printf '1.0\n' >"${test_dir}/test-installed"
		: >"${test_dir}/log"
		read -r -a target_args <<<"$targets"
		"$BASH" "${repo_dir}/lib/commands/command-update" "${target_args[@]}" test
		if [[ "$targets" == *--plugin* ]]; then
			grep -Fx 'plugin update test' "${test_dir}/log" >/dev/null || fail "plugin flag ignored"
		elif grep -q '^plugin update' "${test_dir}/log"; then
			fail "version-only updated plugin definitions"
		fi
		if [[ "$targets" == *--version* ]]; then
			grep -Fx 'install test 2.0' "${test_dir}/log" >/dev/null || fail "version flag ignored"
		elif grep -q '^install ' "${test_dir}/log"; then
			fail "plugin-only installed a tool"
		fi
	done
	export ASDF_TEST_SCENARIO=self-update-fails
	: >"${test_dir}/log"
	if "$BASH" "${repo_dir}/lib/commands/command-update" --all >"${test_dir}/error" 2>&1; then
		fail "self-update failure was not propagated"
	fi
	grep -Fx 'plugin update next' "${test_dir}/log" >/dev/null || fail "self-update failure stopped plugin updates"
	export ASDF_TEST_SCENARIO=success
	: >"${test_dir}/log"
	"$BASH" "${repo_dir}/lib/commands/command-update" --asdf --parent
	[[ "$(<"${test_dir}/log")" == self-update ]] || fail "asdf-only update used irrelevant scope"
	: >"${test_dir}/log"
	"$BASH" "${repo_dir}/lib/commands/command-update" --plugin --parent
	if grep -Eq '^(self-update|install|set|uninstall)' "${test_dir}/log"; then
		fail "plugin-only update did not ignore irrelevant scope"
	fi
done

for scope in --home --parent --local; do
	case "$scope" in
	--home) file="$HOME/.tool-versions" ;;
	--parent) file="${test_dir}/project/.tool-versions" ;;
	--local) file="$PWD/.tool-versions" ;;
	esac
	export ASDF_TEST_SCENARIO=success
	printf 'test 7.0\n' >"$HOME/.tool-versions"
	printf 'test 1.0\n' >"$file"
	printf '1.0\n' >"${test_dir}/test-installed"
	: >"${test_dir}/test-removed"
	: >"${test_dir}/log"
	"$BASH" "${repo_dir}/lib/commands/command-update" test "$scope" 2.0
	grep -Fx 'test 2.0' "$file" >/dev/null || fail "$scope: incorrect scope file"
	if [[ "$scope" != --home ]]; then
		[[ ! -s "${test_dir}/test-removed" ]] || fail "$scope: removed old version"
		grep -Fx 'test 7.0' "$HOME/.tool-versions" >/dev/null || fail "$scope: home configuration changed"
	fi
	: >"${test_dir}/log"
	"$BASH" "${repo_dir}/lib/commands/command-install" "$scope" test 2.0
	if grep -Eq '^(install|set) ' "${test_dir}/log"; then
		fail "$scope: already-configured install was not skipped"
	fi
	"$BASH" "${repo_dir}/lib/commands/command-update" "$scope"
	if grep -q '^plugin update next' "${test_dir}/log"; then
		fail "$scope: bulk update escaped selected configuration"
	fi
	for scenario in install-fails partial-install-fails set-fails set-ineffective; do
		export ASDF_TEST_SCENARIO="$scenario"
		printf 'test 1.0\n' >"$file"
		printf '1.0\n' >"${test_dir}/test-installed"
		: >"${test_dir}/test-removed"
		if "$BASH" "${repo_dir}/lib/commands/command-update" "$scope" test 2.0 >"${test_dir}/error" 2>&1; then
			fail "$scope/$scenario: failure was accepted"
		fi
		grep -Fx 'test 1.0' "$file" >/dev/null || fail "$scope/$scenario: configuration changed"
		[[ ! -s "${test_dir}/test-removed" ]] || fail "$scope/$scenario: previous version removed"
	done
done

export ASDF_TEST_SCENARIO=success
for args in '--home --local test' '--parent --local test' '--current test' 'all 2.0' 'test 2.0 extra' '--all --plugin' '--all test' '--asdf test' '--plugin test 2.0'; do
	: >"${test_dir}/log"
	# Intentional splitting of fixed test arguments.
	read -r -a invalid_args <<<"$args"
	if "$BASH" "${repo_dir}/lib/commands/command-update" "${invalid_args[@]}" >"${test_dir}/error" 2>&1; then
		fail "invalid update arguments accepted: $args"
	fi
	[[ ! -s "${test_dir}/log" ]] || fail "invalid update had side effects"
done

export ASDF_TEST_SCENARIO=unresolved
printf 'test 0.9\nnext 0.9\n' >"$HOME/.tool-versions"
printf '0.9\n' >"${test_dir}/test-current"
printf '0.9\n' >"${test_dir}/test-installed"
: >"${test_dir}/log"
if ! ASDF_EXTRAS_UPDATE_DEFAULT_VERSION=1.0 "$BASH" "${repo_dir}/lib/commands/command-update" test >"${test_dir}/output" 2>&1; then
	fail "global implicit version fallback failed: $(cat "${test_dir}/output")"
fi
grep -Fx 'install test 1.0' "${test_dir}/log" >/dev/null || fail "global implicit version was not used"
if grep -q '^latest test' "${test_dir}/log"; then
	fail "latest resolution ran despite global implicit version"
fi

: >"${test_dir}/log"
if ASDF_EXTRAS_UPDATE_DEFAULT_VERSION=1.0 ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX=24 ASDF_EXTRAS_UPDATE_USE_LATEST=1 "$BASH" "${repo_dir}/lib/commands/command-update" test >"${test_dir}/output" 2>&1; then
	fail "forced latest did not propagate unresolved latest failure"
fi
grep -Fx 'latest test 24' "${test_dir}/log" >/dev/null || fail "forced latest did not use latest-prefix defaults"

export ASDF_TEST_SCENARIO=success
printf 'test 0.9\nnext 0.9\n' >"$HOME/.tool-versions"
printf '0.9\n' >"${test_dir}/test-current"
printf '0.9\n' >"${test_dir}/next-current"
printf '0.9\n' >"${test_dir}/test-installed"
printf '0.9\n' >"${test_dir}/next-installed"
: >"${test_dir}/log"
ASDF_EXTRAS_UPDATE_DEFAULT_VERSION=2.0 ASDF_EXTRAS_UPDATE_DEFAULT_VERSION_TEST=1.0 \
	"$BASH" "${repo_dir}/lib/commands/command-update" --version
grep -Fx 'install test 1.0' "${test_dir}/log" >/dev/null || fail "plugin implicit version override missing"
grep -Fx 'install next 2.0' "${test_dir}/log" >/dev/null || fail "global implicit version missing"

: >"${test_dir}/log"
printf 'test 0.9\n' >"$HOME/.tool-versions"
printf '0.9\n' >"${test_dir}/test-current"
printf '0.9\n' >"${test_dir}/test-installed"
ASDF_EXTRAS_UPDATE_DEFAULT_VERSION=1.0 "$BASH" "${repo_dir}/lib/commands/command-update" --use-latest test
grep -Fx 'latest test' "${test_dir}/log" >/dev/null || fail "--use-latest should use no prefix by default"

: >"${test_dir}/log"
printf 'test 0.9\n' >"$HOME/.tool-versions"
printf '0.9\n' >"${test_dir}/test-current"
printf '0.9\n' >"${test_dir}/test-installed"
"$BASH" "${repo_dir}/lib/commands/command-update" --use-latest test 24
grep -Fx 'latest test 24' "${test_dir}/log" >/dev/null || fail "--use-latest explicit version was not used as prefix"

: >"${test_dir}/log"
printf 'test 0.9\n' >"$HOME/.tool-versions"
printf '0.9\n' >"${test_dir}/test-current"
printf '0.9\n' >"${test_dir}/test-installed"
ASDF_EXTRAS_UPDATE_DEFAULT_VERSION=latest "$BASH" "${repo_dir}/lib/commands/command-update" --use-latest test
grep -Fx 'latest test' "${test_dir}/log" >/dev/null || fail "latest implicit value should resolve without prefix"

printf 'test 0.9\nnext 0.9\n' >"$HOME/.tool-versions"
printf '0.9\n' >"${test_dir}/test-current"
printf '0.9\n' >"${test_dir}/next-current"
printf '0.9\n' >"${test_dir}/test-installed"
printf '0.9\n' >"${test_dir}/next-installed"
: >"${test_dir}/log"
ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX=2 ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX_TEST=1 \
	"$BASH" "${repo_dir}/lib/commands/command-update" --use-latest --version
grep -Fx 'latest test 1' "${test_dir}/log" >/dev/null || fail "plugin latest-prefix override missing"
grep -Fx 'latest next 2' "${test_dir}/log" >/dev/null || fail "global latest-prefix missing"

printf 'test 0.9\nnext 0.9\n' >"$HOME/.tool-versions"
printf '0.9\n' >"${test_dir}/test-current"
printf '0.9\n' >"${test_dir}/next-current"
printf '0.9\n' >"${test_dir}/test-installed"
printf '0.9\n' >"${test_dir}/next-installed"
: >"${test_dir}/log"
ASDF_EXTRAS_UPDATE_DEFAULT_VERSION=2.0 ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX=24 \
	ASDF_EXTRAS_UPDATE_USE_LATEST_TEST=1 "$BASH" "${repo_dir}/lib/commands/command-update" --version
grep -Fx 'latest test 24' "${test_dir}/log" >/dev/null || fail "plugin use-latest flag missing"
grep -Fx 'install next 2.0' "${test_dir}/log" >/dev/null || fail "non-selected plugin should use version mode"

printf 'test 0.9\nnext 0.9\n' >"$HOME/.tool-versions"
printf '0.9\n' >"${test_dir}/test-current"
printf '0.9\n' >"${test_dir}/next-current"
printf '0.9\n' >"${test_dir}/test-installed"
printf '0.9\n' >"${test_dir}/next-installed"
: >"${test_dir}/log"
ASDF_EXTRAS_UPDATE_DEFAULT_VERSION=2.0 ASDF_EXTRAS_UPDATE_DEFAULT_LATEST_PREFIX=24 \
	ASDF_EXTRAS_UPDATE_USE_LATEST=1 ASDF_EXTRAS_UPDATE_USE_LATEST_NEXT=0 \
	"$BASH" "${repo_dir}/lib/commands/command-update" --version
grep -Fx 'latest test 24' "${test_dir}/log" >/dev/null || fail "global use-latest should apply to test"
grep -Fx 'install next 2.0' "${test_dir}/log" >/dev/null || fail "plugin use-latest override should disable next"

rm "${test_dir}/project/.tool-versions"
if "$BASH" "${repo_dir}/lib/commands/command-update" --parent test >"${test_dir}/error" 2>&1; then
	fail "missing parent accepted"
fi
rm "$PWD/.tool-versions"
if "$BASH" "${repo_dir}/lib/commands/command-update" --local >"${test_dir}/error" 2>&1; then
	fail "missing local bulk configuration accepted"
fi
"$BASH" "${repo_dir}/lib/commands/command-update" --local test 2.0
grep -Fx 'test 2.0' "$PWD/.tool-versions" >/dev/null || fail "local configuration not created"

mkdir -p "$ASDF_EXTRAS_INSTALL_ENV_DIR"
cat >"$ASDF_EXTRAS_INSTALL_ENV_DIR/test.env" <<'EOF'
test_install_hook() {
	printf '%s %s\n' "$1" "$2" >>"$ASDF_TEST_DIR/hooks"
}
ASDF_EXTRAS_INSTALL_ENV_FUNCTION_TEST=test_install_hook
EOF
printf 'test 1.0\n' >.tool-versions
"$BASH" "${repo_dir}/lib/commands/command-update" --local test
[[ "$(<"${test_dir}/hooks")" == "test 2.0" ]] || fail "update did not delegate install hooks"
"$BASH" "${repo_dir}/lib/commands/command-update" --local test
[[ "$(wc -l <"${test_dir}/hooks" | tr -d ' ')" == 1 ]] || fail "no-op update ran hooks"

# Each entry point sets its own origin; an inherited origin must not leak into it.
ln -s "$repo_dir" "$test_dir/runtime-dev"
printf 'asdf-extras dev\ntest 1.0\n' >.tool-versions
: >"${test_dir}/nested"
ASDF_EXTRAS_ORIGIN=plugin "${repo_dir}/libexec/asdf-extras" update --local test
[[ "$(<"${test_dir}/nested")" == "$(printf 'exec asdf-extras install --local test latest\nruntime runtime-dev')" ]] ||
	fail "installed-mode install did not use the selected CLI: $(<"${test_dir}/nested")"
printf 'asdf-extras dev\ntest 1.0\n' >.tool-versions
: >"${test_dir}/nested"
ASDF_EXTRAS_ORIGIN=installed "$BASH" "${repo_dir}/lib/commands/command-update" --local test
[[ "$(<"${test_dir}/nested")" == 'cmd asdf-extras install -- --local test latest' ]] ||
	fail "plugin-mode install inherited the installed origin: $(<"${test_dir}/nested")"
printf 'test 1.0\n' >.tool-versions
: >"${test_dir}/nested"
ASDF_EXTRAS_PLUGIN_NAME=custom-extras "$BASH" "${repo_dir}/lib/commands/command-update" --local test
[[ "$(<"${test_dir}/nested")" == 'cmd custom-extras install -- --local test latest' ]] ||
	fail "plugin-mode install ignored the registered plugin name: $(<"${test_dir}/nested")"
rm -f .tool-versions "$test_dir/runtime-dev"

unset ASDF_EXTRAS_INSTALL_ENV_DIR
export ASDF_TEST_RUNTIME_UPDATE=1
for mode in default --all --version --home asdf-extras; do
	for scenario in success install-fails cleanup-fails extras-install-fails extras-set-fails; do
		export ASDF_TEST_SCENARIO="$scenario"
		rm -rf "$test_dir/runtime-2.0"
		: >"$test_dir/nested"
		mkdir -p "$test_dir/runtime-old"
		cp -R "$repo_dir/lib" "$repo_dir/libexec" "$test_dir/runtime-old/"
		printf 'asdf-extras 1.0\ntest 1.0\nnext 1.0\n' >"$HOME/.tool-versions"
		for plugin in asdf-extras test next; do
			printf '1.0\n' >"$test_dir/$plugin-installed"
			: >"$test_dir/$plugin-removed"
		done
		: >"$test_dir/log"
		if [[ "$mode" == default ]]; then
			set --
		else
			set -- "$mode"
		fi
		if "$BASH" "$test_dir/runtime-old/libexec/asdf-extras" update "$@" >"$test_dir/output" 2>&1; then
			[[ "$scenario" == success || ("$mode" == asdf-extras && "$scenario" == install-fails) ]] ||
				fail "$mode/$scenario: runtime update failure suppressed"
		else
			[[ "$scenario" != success ]] || fail "$mode/$scenario: $(cat "$test_dir/output")"
		fi
		if [[ "$mode" != asdf-extras ]]; then
			grep -Fx 'next 2.0' "$HOME/.tool-versions" >/dev/null ||
				fail "$mode/$scenario: subsequent plugin was not activated"
			grep -Fx 'install next 2.0' "$test_dir/log" >/dev/null ||
				fail "$mode/$scenario: subsequent install did not run"
			[[ "$(grep '^install ' "$test_dir/log" | tail -n 1)" == 'install asdf-extras 2.0' ]] ||
				fail "$mode/$scenario: extras install did not run last"
			if [[ "$mode" != --version ]]; then
				[[ "$(grep '^plugin update ' "$test_dir/log" | tail -n 1)" == 'plugin update asdf-extras' ]] ||
					fail "$mode/$scenario: extras plugin update did not run last"
			fi
		fi
		case "$scenario" in
		extras-install-fails | extras-set-fails)
			grep -Fx 'asdf-extras 1.0' "$HOME/.tool-versions" >/dev/null ||
				fail "$mode/$scenario: failed extras update changed selection"
			[[ -d "$test_dir/runtime-old" ]] || fail "failed extras update removed runtime"
			[[ ! -s "$test_dir/asdf-extras-removed" ]] || fail "failed extras update removed old version"
			rm -rf "$test_dir/runtime-old"
			continue
			;;
		esac
		grep -Fx 'asdf-extras 2.0' "$HOME/.tool-versions" >/dev/null ||
			fail "$mode/$scenario: extras was not activated"
		[[ "$(tail -n 1 "$test_dir/log")" == 'uninstall asdf-extras 1.0' ]] ||
			fail "$mode/$scenario: extras cleanup did not run last"
		# The extras install itself runs in the runtime selected before the switch.
		grep -Fx 'exec asdf-extras install --home asdf-extras latest' "$test_dir/nested" >/dev/null ||
			fail "$mode/$scenario: extras install did not use the installed CLI"
		if [[ "$scenario" == cleanup-fails ]]; then
			[[ -d "$test_dir/runtime-old" ]] || fail "failed cleanup removed runtime"
			grep -q 'failed to remove previous version: asdf-extras' "$test_dir/output" ||
				fail "cleanup failure not reported"
			rm -rf "$test_dir/runtime-old"
		else
			[[ ! -d "$test_dir/runtime-old" ]] || fail "$mode/$scenario: old extras runtime retained"
		fi
		# Later nested commands follow the new selection after the old runtime is gone.
		: >"$test_dir/nested"
		ASDF_TEST_SCENARIO=success ASDF_TEST_RUNTIME_UPDATE=0 \
			"$BASH" "$test_dir/runtime-2.0/libexec/asdf-extras" update --version test >"$test_dir/output" 2>&1 ||
			fail "$mode/$scenario: update after self-update failed: $(cat "$test_dir/output")"
		[[ "$(tail -n 1 "$test_dir/nested")" == 'runtime runtime-2.0' ]] ||
			fail "$mode/$scenario: nested command did not use the selected runtime"
	done
done

export ASDF_TEST_SCENARIO=success
for mode in --plugin --local --parent; do
	rm -rf "$test_dir/runtime-2.0"
	: >"$test_dir/nested"
	mkdir -p "$test_dir/runtime-old"
	cp -R "$repo_dir/lib" "$repo_dir/libexec" "$test_dir/runtime-old/"
	printf 'asdf-extras 1.0\nnext 1.0\n' >"$HOME/.tool-versions"
	printf '1.0\n' >"$test_dir/asdf-extras-installed"
	printf '1.0\n' >"$test_dir/next-installed"
	case "$mode" in
	--local) file="$PWD/.tool-versions" ;;
	--parent) file="$test_dir/project/.tool-versions" ;;
	--plugin) file="$HOME/.tool-versions" ;;
	esac
	printf 'asdf-extras 1.0\nnext 1.0\n' >"$file"
	: >"$test_dir/log"
	"$BASH" "$test_dir/runtime-old/libexec/asdf-extras" update "$mode"
	[[ -d "$test_dir/runtime-old" ]] || fail "$mode: old runtime unexpectedly removed"
	[[ "$(grep '^plugin update ' "$test_dir/log" | head -n 1)" == 'plugin update asdf-extras' ]] ||
		fail "$mode: original plugin order changed"
	if [[ "$mode" == --plugin ]]; then
		if grep -q '^install ' "$test_dir/log"; then
			fail "plugin-only update installed tools"
		fi
	else
		grep -Fx 'asdf-extras 2.0' "$file" >/dev/null || fail "$mode: scope activation missing"
		grep -Fx 'asdf-extras 1.0' "$HOME/.tool-versions" >/dev/null || fail "$mode: home modified"
		# The scope now selects the new extras version, so the next install uses it.
		[[ "$(tail -n 2 "$test_dir/nested")" == "$(printf 'exec asdf-extras install %s next latest\nruntime runtime-2.0' "$mode")" ]] ||
			fail "$mode: nested install did not follow the selection change"
		printf 'next 1.0\n' >"$file"
		printf '1.0\n' >"$test_dir/next-installed"
		: >"$test_dir/log"
		"$BASH" "$test_dir/runtime-old/libexec/asdf-extras" update "$mode"
		if grep -q asdf-extras "$test_dir/log"; then
			fail "$mode: extras updated despite not being selected"
		fi
	fi
	rm -rf "$test_dir/runtime-old"
done

export ASDF_EXTRAS_PLUGIN_NAME=custom-extras
for mode in default --version --home --local --parent --plugin custom-extras; do
	mkdir -p "$test_dir/runtime-old"
	cp -R "$repo_dir/lib" "$repo_dir/libexec" "$test_dir/runtime-old/"
	printf 'custom-extras 1.0\ntest 1.0\nnext 1.0\n' >"$HOME/.tool-versions"
	for plugin in custom-extras test next; do
		printf '1.0\n' >"$test_dir/$plugin-installed"
	done
	case "$mode" in
	--local) file="$PWD/.tool-versions" ;;
	--parent) file="$test_dir/project/.tool-versions" ;;
	*) file="$HOME/.tool-versions" ;;
	esac
	cp "$HOME/.tool-versions" "$test_dir/selected-versions"
	cp "$test_dir/selected-versions" "$file"
	: >"$test_dir/log"
	if [[ "$mode" == default ]]; then
		set --
	else
		set -- "$mode"
	fi
	"$BASH" "$test_dir/runtime-old/libexec/asdf-extras" update "$@" >"$test_dir/output" 2>&1 ||
		fail "$mode: custom extras update failed: $(cat "$test_dir/output")"
	case "$mode" in
	--local | --parent | --plugin)
		[[ -d "$test_dir/runtime-old" ]] || fail "$mode: retained runtime removed"
		[[ "$(grep '^plugin update ' "$test_dir/log" | head -n 1)" == 'plugin update custom-extras' ]] ||
			fail "$mode: custom name changed retained-runtime update order"
		rm -rf "$test_dir/runtime-old"
		;;
	*)
		[[ ! -d "$test_dir/runtime-old" ]] || fail "$mode: custom extras runtime not cleaned"
		[[ "$(tail -n 1 "$test_dir/log")" == 'uninstall custom-extras 1.0' ]] ||
			fail "$mode: custom extras update did not run last"
		;;
	esac
	if [[ "$mode" != --plugin ]]; then
		grep -Fx 'custom-extras 2.0' "$file" >/dev/null || fail "$mode: custom extras not activated"
	fi
done
unset ASDF_EXTRAS_PLUGIN_NAME

printf 'update regression tests: PASS\n'

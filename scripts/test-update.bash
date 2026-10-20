#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export ASDF_TEST_DIR="$test_dir"
export PATH="${test_dir}:$PATH"

cat >"${test_dir}/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$ASDF_TEST_DIR/log"
case "$1" in
plugin)
	if [[ "$2" == list ]]; then
		printf 'test\nnext\n'
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
	if [[ "$2" == test ]]; then
		case "$ASDF_TEST_SCENARIO" in
		install-fails) exit 1 ;;
		partial-install-fails)
			printf '2.0\n' >>"$ASDF_TEST_DIR/$2-installed"
			exit 1
			;;
		missing-install) exit 0 ;;
		esac
	fi
	printf '2.0\n' >>"$ASDF_TEST_DIR/$2-installed"
	;;
set)
	if [[ "$3" == test ]]; then
		case "$ASDF_TEST_SCENARIO" in
		set-fails) exit 1 ;;
		set-ineffective) exit 0 ;;
		esac
	fi
	printf '%s\n' "$4" >"$ASDF_TEST_DIR/$3-current"
	;;
uninstall)
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
		expected="$(printf 'install test 2.0\nset -u test 2.0\nuninstall test 1.0')"
		[[ "$(grep -E '^(install|set|uninstall) .*test ' "${test_dir}/log")" == "$expected" ]] ||
			fail "incorrect install/activation/removal order"
	else
		[[ ! -s "${test_dir}/test-removed" ]] || fail "$mode/$scenario: previous version was removed"
		[[ "$(<"${test_dir}/test-current")" == 1.0 ]] || fail "$mode/$scenario: selection changed"
		[[ "$output" == *"asdf-extras:"* ]] || fail "$mode/$scenario: no error reported"
		case "$scenario" in
		install-fails | partial-install-fails | missing-install | unresolved)
			if grep -q '^set -u test ' "${test_dir}/log"; then
				fail "$mode/$scenario: activation attempted after install failure"
			fi
			;;
		esac
		if [[ "$mode" == test ]]; then
			[[ $rc -ne 0 ]] || fail "$mode/$scenario: failure was not propagated"
		else
			[[ "$(<"${test_dir}/next-current")" == 2.0 ]] || fail "$mode/$scenario: next plugin was not updated"
		fi
	fi
}

printf 'Testing update with Bash %s\n' "$BASH_VERSION"
for mode in test all default; do
	for scenario in success install-fails partial-install-fails missing-install set-fails set-ineffective unresolved; do
		run_case "$scenario" "$mode"
	done
done
printf 'update regression tests: PASS\n'

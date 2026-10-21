#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
test_dir="$test_root/runtime with spaces"
export ASDF_REFRESH_TEST_DIR="$test_dir"
export PATH="$test_dir/bin:$PATH"
mkdir -p "$test_dir/bin"

cat >"$test_dir/bin/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == "which asdf-extras" ]]; then
	if [[ "$ASDF_REFRESH_SCENARIO" == resolution-failure ]] &&
		grep -q '/new/' "$ASDF_REFRESH_TEST_DIR/selected"; then
		exit 4
	fi
	cat "$ASDF_REFRESH_TEST_DIR/selected"
elif [[ "$*" == "completion bash" ]]; then
	printf '_test_native_complete() { COMPREPLY=(); }\ncomplete -F _test_native_complete asdf\n'
elif [[ "$*" == "completion zsh" ]]; then
	printf 'return 0\n'
elif [[ "$*" == "completion fish" ]]; then
	printf 'complete -c asdf -f\n'
else
	printf 'native %s\n' "$*" >>"$ASDF_REFRESH_TEST_DIR/log"
fi
EOF
chmod +x "$test_dir/bin/asdf"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

for shell_name in bash zsh fish; do
	if ! command -v "$shell_name" >/dev/null; then
		printf 'SKIP: %s is unavailable\n' "$shell_name"
		continue
	fi
	for scenario in success partial-failure unchanged failed-update generation-failure empty-init evaluation-failure resolution-failure; do
		export ASDF_REFRESH_SCENARIO="$scenario"
		mkdir -p "$test_dir/old" "$test_dir/new"
		for runtime in old new; do
			cp -R "$repo_dir/lib" "$repo_dir/libexec" "$test_dir/$runtime/"
			mkdir -p "$test_dir/$runtime/bin"
			cat >"$test_dir/$runtime/bin/asdf-extras" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$ASDF_REFRESH_SCENARIO" == generation-failure ]]; then
	printf 'echo must-not-evaluate\n'
	exit 3
fi
if [[ "$ASDF_REFRESH_SCENARIO" == empty-init ]]; then
	exit 0
fi
if [[ "$ASDF_REFRESH_SCENARIO" == evaluation-failure ]]; then
	printf 'false\n'
	exit 0
fi
root="$(dirname "$(dirname "$0")")"
shift
exec bash "$root/lib/commands/command-init" "$@"
EOF
			chmod +x "$test_dir/$runtime/bin/asdf-extras"
		done
		cat >"$test_dir/old/lib/commands/dispatch.bash" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'update\n' >>"$ASDF_REFRESH_TEST_DIR/log"
case "$ASDF_REFRESH_SCENARIO" in
unchanged) exit 0 ;;
failed-update) exit 7 ;;
esac
printf '%s/new/bin/asdf-extras\n' "$ASDF_REFRESH_TEST_DIR" >"$ASDF_REFRESH_TEST_DIR/selected"
rm -rf "$ASDF_REFRESH_TEST_DIR/old"
[[ "$ASDF_REFRESH_SCENARIO" != partial-failure ]] || exit 7
EOF
		cat >"$test_dir/new/lib/commands/dispatch.bash" <<'EOF'
#!/usr/bin/env bash
printf 'new %s\n' "$*" >>"$ASDF_REFRESH_TEST_DIR/log"
EOF
		printf '%s/old/bin/asdf-extras\n' "$test_dir" >"$test_dir/selected"
		: >"$test_dir/log"
		case "$scenario" in
		success | unchanged) expected=0 ;;
		partial-failure | failed-update) expected=7 ;;
		generation-failure | empty-init | evaluation-failure | resolution-failure) expected=1 ;;
		esac
		export ASDF_REFRESH_EXPECTED="$expected"
		if [[ "$shell_name" == fish ]]; then
			# shellcheck disable=SC2016
			"$shell_name" -c '
				set -gx ASDF_EXTRAS_DISPATCHER "$ASDF_REFRESH_TEST_DIR/old/lib/commands/dispatch.bash"
				source "$ASDF_REFRESH_TEST_DIR/old/lib/init/fish.fish"
				asdf update
				set -l rc $status
				test $rc -eq $ASDF_REFRESH_EXPECTED; or exit 90
				if test "$ASDF_REFRESH_SCENARIO" = success; or test "$ASDF_REFRESH_SCENARIO" = partial-failure
					asdf install --local test 2.0
					asdf install --local test 2.0
					asdf update
					test $status -eq 0; or exit 91
					asdf install --local test 2.0
				end
			' || fail "$shell_name/$scenario"
		else
			# shellcheck disable=SC2016
			"$shell_name" -c '
				ASDF_EXTRAS_DISPATCHER="$ASDF_REFRESH_TEST_DIR/old/lib/commands/dispatch.bash"
				source "$ASDF_REFRESH_TEST_DIR/old/lib/init/$1"
				if asdf update; then rc=0; else rc=$?; fi
				[[ "$rc" == "$ASDF_REFRESH_EXPECTED" ]] || exit 90
				case "$ASDF_REFRESH_SCENARIO" in
				success|partial-failure)
					asdf install --local test 2.0
					asdf install --local test 2.0
					asdf update || exit 91
					asdf install --local test 2.0
					;;
				esac
			' -- "$([[ "$shell_name" == bash ]] && printf bash.sh || printf zsh.zsh)" ||
				fail "$shell_name/$scenario"
		fi
		if [[ "$scenario" == success || "$scenario" == partial-failure ]]; then
			[[ "$(grep -c '^new install' "$test_dir/log")" == 3 ]] || fail "$shell_name: stale runtime or duplicate invocation"
		fi
	done
done

cat >"$test_dir/notice-dispatch.bash" <<'EOF'
#!/usr/bin/env bash
printf 'update-output\n'
exit "${ASDF_NOTICE_STATUS:-0}"
EOF
export ASDF_EXTRAS_DISPATCHER="$test_dir/notice-dispatch.bash"
for shell_name in elvish nu; do
	if ! command -v "$shell_name" >/dev/null; then
		printf 'SKIP: %s is unavailable\n' "$shell_name"
		continue
	fi
	for expected in 0 7; do
		export ASDF_NOTICE_STATUS="$expected"
		if [[ "$shell_name" == elvish ]]; then
			code="$(<"$repo_dir/lib/init/elvish.elv")"$'\nasdf update'
		else
			code="source '$repo_dir/lib/init/nushell.nu'; asdf update; exit \$env.LAST_EXIT_CODE"
		fi
		if "$shell_name" -c "$code" >"$test_dir/stdout" 2>"$test_dir/stderr"; then
			rc=0
		else
			rc=$?
		fi
		if [[ "$expected" == 0 ]]; then
			[[ "$rc" == 0 ]] || fail "$shell_name: successful update failed"
		else
			[[ "$rc" != 0 ]] || fail "$shell_name: update failure was hidden"
		fi
		grep -Fx update-output "$test_dir/stdout" >/dev/null || fail "$shell_name: update output lost"
		grep -F 'start a new' "$test_dir/stderr" >/dev/null || fail "$shell_name: reload reminder missing"
	done
done
printf 'shell initialization refresh tests: PASS\n'

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
elif [[ "${1:-}" == exec && "${2:-}" == asdf-extras ]]; then
	shift 2
	exec "$(cat "$ASDF_REFRESH_TEST_DIR/selected")" "$@"
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

prepare_runtimes() {
	local runtime
	mkdir -p "$test_dir/old" "$test_dir/new"
	for runtime in old new; do
		cp -R "$repo_dir/lib" "$repo_dir/libexec" "$test_dir/$runtime/"
		mkdir -p "$test_dir/$runtime/bin"
		cat >"$test_dir/$runtime/bin/asdf-extras" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
subcommand="$1"
root="$(dirname "$(dirname "$0")")"
if [[ "$subcommand" == completion && "$ASDF_REFRESH_SCENARIO" == completion-generation-failure ]]; then
	printf 'echo must-not-evaluate\n'
	exit 3
fi
if [[ "$subcommand" == init ]]; then
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
fi
if [[ "$subcommand" == update && "$(basename "$root")" == old ]]; then
	printf 'update\n' >>"$ASDF_REFRESH_TEST_DIR/log"
	case "$ASDF_REFRESH_SCENARIO" in
	unchanged) exit 0 ;;
	failed-update) exit 7 ;;
	esac
	printf '%s/new/bin/asdf-extras\n' "$ASDF_REFRESH_TEST_DIR" >"$ASDF_REFRESH_TEST_DIR/selected"
	rm -rf "$ASDF_REFRESH_TEST_DIR/old"
	[[ "$ASDF_REFRESH_SCENARIO" != partial-failure ]] || exit 7
	exit 0
fi
if [[ "$subcommand" != init && "$subcommand" != completion && "$(basename "$root")" == new ]]; then
	printf 'new %s\n' "$*" >>"$ASDF_REFRESH_TEST_DIR/log"
	exit 0
fi
exec bash "$root/libexec/asdf-extras" "$@"
EOF
		chmod +x "$test_dir/$runtime/bin/asdf-extras"
	done
	printf '%s/old/bin/asdf-extras\n' "$test_dir" >"$test_dir/selected"
	: >"$test_dir/log"
}

for shell_name in bash zsh fish; do
	if ! command -v "$shell_name" >/dev/null; then
		printf 'SKIP: %s is unavailable\n' "$shell_name"
		continue
	fi
	for scenario in success partial-failure unchanged failed-update generation-failure empty-init evaluation-failure resolution-failure; do
		export ASDF_REFRESH_SCENARIO="$scenario"
		prepare_runtimes
		case "$scenario" in
		success | unchanged) expected=0 ;;
		partial-failure | failed-update) expected=7 ;;
		generation-failure | empty-init | evaluation-failure | resolution-failure) expected=1 ;;
		esac
		export ASDF_REFRESH_EXPECTED="$expected"
		if [[ "$shell_name" == fish ]]; then
			# shellcheck disable=SC2016
			"$shell_name" -c '
				set -gx ASDF_EXTRAS_INIT_ORIGIN installed
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
				ASDF_EXTRAS_INIT_ORIGIN=installed
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

# init does not load completion, so an update reloads it only where it was enabled.
for shell_name in bash zsh fish; do
	if ! command -v "$shell_name" >/dev/null; then
		printf 'SKIP: %s is unavailable\n' "$shell_name"
		continue
	fi
	for completion_mode in none standalone combined; do
		for scenario in success unchanged completion-generation-failure; do
			export ASDF_REFRESH_SCENARIO="$scenario" ASDF_REFRESH_COMPLETION="$completion_mode"
			prepare_runtimes
			expected=0
			[[ "$scenario" != completion-generation-failure || "$completion_mode" == none ]] || expected=1
			export ASDF_REFRESH_EXPECTED="$expected"
			# Completion loaded by hand comes from the plugin; a reload by the selected
			# executable comes from the installed entry point.
			if [[ "$scenario" == success ]]; then
				export ASDF_REFRESH_COMPLETION_ORIGIN=installed
			else
				export ASDF_REFRESH_COMPLETION_ORIGIN=plugin
			fi
			if [[ "$shell_name" == fish ]]; then
				# shellcheck disable=SC2016
				"$shell_name" -c '
					set -gx ASDF_EXTRAS_INIT_ORIGIN installed
					source "$ASDF_REFRESH_TEST_DIR/old/lib/init/fish.fish"
					test -z "$ASDF_EXTRAS_COMPLETION_ORIGIN"; or exit 80
					switch "$ASDF_REFRESH_COMPLETION"
					case standalone
						bash "$ASDF_REFRESH_TEST_DIR/old/lib/commands/command-completion" fish | source
					case combined
						bash "$ASDF_REFRESH_TEST_DIR/old/lib/commands/command-completion" --asdf fish | source
					end
					asdf update
					set -l rc $status
					test $rc -eq $ASDF_REFRESH_EXPECTED; or exit 90
					set -l origin "$ASDF_EXTRAS_COMPLETION_ORIGIN"
					if test "$ASDF_REFRESH_COMPLETION" = none
						test -z "$origin"; or exit 91
						if set -q __asdf_extras_completion_registered
							exit 92
						end
						if set -q __asdf_extras_standalone_registered
							exit 93
						end
					else
						test "$origin" = "$ASDF_REFRESH_COMPLETION_ORIGIN"; or exit 94
						if test "$ASDF_REFRESH_COMPLETION" = combined
							set -q __asdf_extras_completion_registered; or exit 95
						else if set -q __asdf_extras_completion_registered
							exit 96
						end
					end
				' || fail "$shell_name/$completion_mode/$scenario: completion reload (status $?)"
			else
				# shellcheck disable=SC2016
				"$shell_name" -c '
					ASDF_EXTRAS_INIT_ORIGIN=installed
					source "$ASDF_REFRESH_TEST_DIR/old/lib/init/$1"
					[[ -z "${ASDF_EXTRAS_COMPLETION_ORIGIN:-}" ]] || exit 80
					case "$ASDF_REFRESH_COMPLETION" in
					standalone) eval "$(bash "$ASDF_REFRESH_TEST_DIR/old/lib/commands/command-completion" "$2")" ;;
					combined) eval "$(bash "$ASDF_REFRESH_TEST_DIR/old/lib/commands/command-completion" --asdf "$2")" ;;
					esac
					if asdf update; then rc=0; else rc=$?; fi
					[[ "$rc" == "$ASDF_REFRESH_EXPECTED" ]] || exit 90
					origin="${ASDF_EXTRAS_COMPLETION_ORIGIN:-}"
					if [[ "$ASDF_REFRESH_COMPLETION" == none ]]; then
						[[ -z "$origin" && -z "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]] || exit 91
					else
						[[ "$origin" == "$ASDF_REFRESH_COMPLETION_ORIGIN" ]] || exit 94
						if [[ "$ASDF_REFRESH_COMPLETION" == combined ]]; then
							[[ -n "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]] || exit 95
						else
							[[ -z "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]] || exit 96
						fi
					fi
				' -- "$([[ "$shell_name" == bash ]] && printf bash.sh || printf zsh.zsh)" "$shell_name" ||
					fail "$shell_name/$completion_mode/$scenario: completion reload (status $?)"
			fi
		done
	done
done

# asdf reload loads changed definitions on demand: the selected runtime does not
# change, and completion keeps its mode. The marker is appended to the init file
# after the shell loaded it, so it only appears if reload evaluated it again.
for shell_name in bash zsh fish; do
	if ! command -v "$shell_name" >/dev/null; then
		printf 'SKIP: %s is unavailable\n' "$shell_name"
		continue
	fi
	for completion_mode in none standalone combined; do
		for scenario in success generation-failure completion-generation-failure; do
			export ASDF_REFRESH_SCENARIO="$scenario" ASDF_REFRESH_COMPLETION="$completion_mode"
			prepare_runtimes
			expected=0
			case "$scenario" in
			generation-failure) expected=1 ;;
			completion-generation-failure) [[ "$completion_mode" == none ]] || expected=1 ;;
			esac
			export ASDF_REFRESH_EXPECTED="$expected"
			# A failed generation leaves what was loaded by hand, which came from the plugin.
			export ASDF_REFRESH_COMPLETION_ORIGIN=plugin
			[[ "$scenario" != success ]] || export ASDF_REFRESH_COMPLETION_ORIGIN=installed
			if [[ "$shell_name" == fish ]]; then
				# shellcheck disable=SC2016
				"$shell_name" -c '
					set -gx ASDF_EXTRAS_INIT_ORIGIN installed
					source "$ASDF_REFRESH_TEST_DIR/old/lib/init/fish.fish"
					switch "$ASDF_REFRESH_COMPLETION"
					case standalone
						bash "$ASDF_REFRESH_TEST_DIR/old/lib/commands/command-completion" fish | source
					case combined
						bash "$ASDF_REFRESH_TEST_DIR/old/lib/commands/command-completion" --asdf fish | source
					end
					echo "set -g ASDF_TEST_RELOADED 1" >>"$ASDF_REFRESH_TEST_DIR/old/lib/init/fish.fish"
					asdf reload extra 2>/dev/null; and exit 81
					set -q ASDF_TEST_RELOADED; and exit 82
					asdf reload
					set -l rc $status
					test $rc -eq $ASDF_REFRESH_EXPECTED; or exit 90
					if test "$ASDF_REFRESH_SCENARIO" = generation-failure
						set -q ASDF_TEST_RELOADED; and exit 91
					else
						set -q ASDF_TEST_RELOADED; or exit 92
					end
					if test "$ASDF_REFRESH_COMPLETION" = none
						test -z "$ASDF_EXTRAS_COMPLETION_ORIGIN"; or exit 93
					else
						test "$ASDF_EXTRAS_COMPLETION_ORIGIN" = "$ASDF_REFRESH_COMPLETION_ORIGIN"; or exit 94
						if test "$ASDF_REFRESH_COMPLETION" = combined
							set -q __asdf_extras_completion_registered; or exit 95
						else if set -q __asdf_extras_completion_registered
							exit 96
						end
					end
				' || fail "$shell_name/$completion_mode/$scenario: reload (status $?)"
			else
				# shellcheck disable=SC2016
				"$shell_name" -c '
					ASDF_EXTRAS_INIT_ORIGIN=installed
					source "$ASDF_REFRESH_TEST_DIR/old/lib/init/$1"
					case "$ASDF_REFRESH_COMPLETION" in
					standalone) eval "$(bash "$ASDF_REFRESH_TEST_DIR/old/lib/commands/command-completion" "$2")" ;;
					combined) eval "$(bash "$ASDF_REFRESH_TEST_DIR/old/lib/commands/command-completion" --asdf "$2")" ;;
					esac
					printf "\nASDF_TEST_RELOADED=1\n" >>"$ASDF_REFRESH_TEST_DIR/old/lib/init/bash.sh"
					if asdf reload extra 2>/dev/null; then exit 81; fi
					[[ -z "${ASDF_TEST_RELOADED:-}" ]] || exit 82
					if asdf reload; then rc=0; else rc=$?; fi
					[[ "$rc" == "$ASDF_REFRESH_EXPECTED" ]] || exit 90
					if [[ "$ASDF_REFRESH_SCENARIO" == generation-failure ]]; then
						[[ -z "${ASDF_TEST_RELOADED:-}" ]] || exit 91
					else
						[[ -n "${ASDF_TEST_RELOADED:-}" ]] || exit 92
					fi
					origin="${ASDF_EXTRAS_COMPLETION_ORIGIN:-}"
					if [[ "$ASDF_REFRESH_COMPLETION" == none ]]; then
						[[ -z "$origin" && -z "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]] || exit 93
					else
						[[ "$origin" == "$ASDF_REFRESH_COMPLETION_ORIGIN" ]] || exit 94
						if [[ "$ASDF_REFRESH_COMPLETION" == combined ]]; then
							[[ -n "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]] || exit 95
						else
							[[ -z "${_ASDF_EXTRAS_NATIVE_COMPLETE:-}" ]] || exit 96
						fi
					fi
				' -- "$([[ "$shell_name" == bash ]] && printf bash.sh || printf zsh.zsh)" "$shell_name" ||
					fail "$shell_name/$completion_mode/$scenario: reload (status $?)"
			fi
		done
	done
	# The runtime did not change, so nothing was updated or uninstalled.
	grep -q '^update' "$test_dir/log" && fail "$shell_name: reload ran an update"
done

mkdir -p "$test_dir/notice"
cat >"$test_dir/notice/asdf" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2" == "exec asdf-extras" ]] || exit 64
printf 'update-output\n'
exit "${ASDF_NOTICE_STATUS:-0}"
EOF
chmod +x "$test_dir/notice/asdf"
export PATH="$test_dir/notice:$PATH" ASDF_EXTRAS_INIT_ORIGIN=installed
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
	# Neither shell can replace loaded definitions, so asdf reload must say so, not succeed.
	if [[ "$shell_name" == elvish ]]; then
		code="$(<"$repo_dir/lib/init/elvish.elv")"$'\nasdf reload'
	else
		code="source '$repo_dir/lib/init/nushell.nu'; asdf reload"
	fi
	if "$shell_name" -c "$code" >"$test_dir/stdout" 2>"$test_dir/stderr"; then
		fail "$shell_name: asdf reload reported success"
	fi
	grep -F 'start a new' "$test_dir/stderr" >/dev/null || fail "$shell_name: reload explanation missing"
done
printf 'shell initialization refresh tests: PASS\n'

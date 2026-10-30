#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
running=""
trap '[[ -z "$running" ]] || kill "$running" 2>/dev/null; rm -rf "$test_root"' EXIT
export ASDF_SHELL_REPO="$repo_dir"
export HOME="$test_root/home"
export PATH="$test_root/bin:$PATH"
mkdir -p "$HOME" "$test_root/bin" "$test_root/work"
cd "$test_root/work"
unset ASDF_PYTHON_VERSION ASDF_NODEJS_VERSION ASDF_MY_TOOL_VERSION ASDF_A_B_C_VERSION

# Stand in for the entry points the wrappers use and for native asdf.
cat >"$test_root/bin/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == exec && "${2:-}" == asdf-extras ]]; then
	shift 2
	exec bash "$ASDF_SHELL_REPO/libexec/asdf-extras" "$@"
fi
printf 'NATIVE: %s\n' "$*"
EOF
chmod +x "$test_root/bin/asdf"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

entry="$repo_dir/libexec/asdf-extras"
export ASDF_EXTRAS_INIT_ORIGIN=installed

run_shell() {
	local shell="$1" request="$2" init_file
	case "$shell" in
	bash | zsh)
		init_file=bash.sh
		[[ "$shell" != zsh ]] || init_file=zsh.zsh
		printf "source \"\$ASDF_SHELL_REPO/lib/init/%s\"\nsource \"\$ASDF_SHELL_REPO/lib/init/%s\"\n%s\n" \
			"$init_file" "$init_file" "$request" >"$test_root/test"
		"$shell" "$test_root/test"
		;;
	fish)
		printf "source \"\$ASDF_SHELL_REPO/lib/init/fish.fish\"\nsource \"\$ASDF_SHELL_REPO/lib/init/fish.fish\"\n%s\n" "$request" >"$test_root/test"
		fish "$test_root/test"
		;;
	elvish)
		cat >"$test_root/test" <<'EOF'
var asdf~ = $nil
eval (e:cat $E:ASDF_SHELL_REPO'/lib/init/elvish.elv' | slurp) &on-end={|ns| set asdf~ = $ns[asdf~]}
eval (e:cat $E:ASDF_SHELL_REPO'/lib/init/elvish.elv' | slurp) &on-end={|ns| set asdf~ = $ns[asdf~]}
EOF
		printf '%s\n' "$request" >>"$test_root/test"
		elvish "$test_root/test"
		;;
	nushell)
		printf "source '%s/init.nu'\nsource '%s/init.nu'\n%s\nexit (\$env.LAST_EXIT_CODE? | default 0)\n" \
			"$test_root" "$test_root" "$request" >"$test_root/test.nu"
		nu --no-config-file "$test_root/test.nu"
		;;
	esac
}

# Runs asdf shell with the arguments as written and keeps going if it fails.
attempt() {
	case "$1" in
	elvish) printf 'try { asdf shell %s } catch _ { }\n' "$2" ;;
	nushell) printf 'try { asdf shell %s } catch { }\n' "$2" ;;
	*) printf 'asdf shell %s; true\n' "$2" ;;
	esac
}

bash "$entry" init nushell >"$test_root/init.nu"

# An invalid request must fail and leave the environment as it was.
invalid_requests=(
	""
	"python"
	"python 'bad version'"
	"'bad plugin' 1.0.0"
	"-x 1.0.0"
	"python -1"
	"python ''"
	"'' 1.0.0"
	"'py;thon' 1.0.0"
	"'py\$(touch PWNED)' 1.0.0"
	"python '\$(touch PWNED)'"
	"python '1.0.0;touch PWNED'"
	"python '1.0.0' 'a|b'"
	"--unset"
	"--unset python extra"
	"--unset 'bad plugin'"
	"--unset '\$(touch PWNED)'"
)

for shell in bash zsh fish elvish nushell; do
	executable="$shell"
	[[ "$shell" != nushell ]] || executable=nu
	if ! command -v "$executable" >/dev/null; then
		printf 'SKIP: %s is unavailable\n' "$shell"
		continue
	fi
	case "$shell" in
	elvish) external=e:env native_command=e:asdf ;;
	nushell) external='^env' native_command='^asdf' ;;
	*) external=env native_command='command asdf' ;;
	esac

	printf '%s\n' 'python 3.12.0' >"$HOME/.tool-versions"
	printf '%s\n' 'nodejs 22.1.0' >.tool-versions
	snapshot="$(find "$test_root/home" "$test_root/work" -type f -exec cksum {} + | sort)"

	# Setting changes the shell and its child processes; the last request wins.
	run_shell "$shell" "$(printf '%s\n' "asdf shell python 3.13.0" "asdf shell python 3.14.0" "$external")" >"$test_root/env"
	grep -Fx 'ASDF_PYTHON_VERSION=3.14.0' "$test_root/env" >/dev/null || fail "$shell: set did not reach a child process"
	[[ "$(grep -c '^ASDF_PYTHON_VERSION=' "$test_root/env")" == 1 ]] || fail "$shell: duplicate override"

	# Tool names are normalized like native asdf: uppercase, - as _.
	run_shell "$shell" "$(printf '%s\n' "asdf shell my-tool 1.0.0" "asdf shell NodeJS 22.2.0" "asdf shell a-b-c 3" "$external")" >"$test_root/env"
	for expected in ASDF_MY_TOOL_VERSION=1.0.0 ASDF_NODEJS_VERSION=22.2.0 ASDF_A_B_C_VERSION=3; do
		grep -Fx "$expected" "$test_root/env" >/dev/null || fail "$shell: missing $expected"
	done

	# Several versions form one ordered list, including fallbacks.
	run_shell "$shell" "$(printf '%s\n' "asdf shell python 3.12.0 3.11.0 system" "$external")" >"$test_root/env"
	grep -Fx 'ASDF_PYTHON_VERSION=3.12.0 3.11.0 system' "$test_root/env" >/dev/null || fail "$shell: version list"
	run_shell "$shell" "$(printf '%s\n' "asdf shell python ref:main" "asdf shell nodejs path:/opt/node" "$external")" >"$test_root/env"
	grep -Fx 'ASDF_PYTHON_VERSION=ref:main' "$test_root/env" >/dev/null || fail "$shell: ref version"
	grep -Fx 'ASDF_NODEJS_VERSION=path:/opt/node' "$test_root/env" >/dev/null || fail "$shell: path version"

	# --unset removes only the named override, and is harmless when nothing is set.
	run_shell "$shell" "$(printf '%s\n' "asdf shell python 3.14.0" "asdf shell nodejs 22.2.0" "asdf shell --unset python" "asdf shell --unset a-b-c" "$external")" >"$test_root/env"
	! grep -q '^ASDF_PYTHON_VERSION=' "$test_root/env" || fail "$shell: unset left the override"
	grep -Fx 'ASDF_NODEJS_VERSION=22.2.0' "$test_root/env" >/dev/null || fail "$shell: unset removed another tool"

	# Invalid arguments fail without evaluating anything.
	for request in "${invalid_requests[@]}"; do
		if run_shell "$shell" "asdf shell $request" >"$test_root/output" 2>"$test_root/error"; then
			fail "$shell: accepted asdf shell $request"
		fi
		[[ -s "$test_root/error" ]] || fail "$shell: no diagnostic for asdf shell $request"
		[[ ! -e PWNED ]] || fail "$shell: evaluated an argument of asdf shell $request"
	done
	# ... and without partly changing an existing override.
	script="$(printf '%s\n' "asdf shell python 1.0.0")"
	for request in "${invalid_requests[@]}"; do
		script+=$'\n'"$(attempt "$shell" "$request")"
	done
	script+=$'\n'"$(attempt "$shell" "python 2.0.0 'bad version'")"
	script+=$'\n'"$external"
	run_shell "$shell" "$script" >"$test_root/env" 2>/dev/null
	grep -Fx 'ASDF_PYTHON_VERSION=1.0.0' "$test_root/env" >/dev/null || fail "$shell: invalid request changed the override"
	[[ ! -e PWNED ]] || fail "$shell: evaluated an argument"

	# Nothing on disk changed.
	[[ "$(find "$test_root/home" "$test_root/work" -type f -exec cksum {} + | sort)" == "$snapshot" ]] ||
		fail "$shell: files were created or modified"

	# A shell that was already running keeps its own environment.
	mkfifo "$test_root/fifo"
	bash -c 'read -r _ <"$1"; env' _ "$test_root/fifo" >"$test_root/running" &
	running=$!
	run_shell "$shell" "asdf shell python 3.14.0" >/dev/null
	printf 'go\n' >"$test_root/fifo"
	wait "$running"
	running=""
	rm -f "$test_root/fifo"
	! grep -q '^ASDF_PYTHON_VERSION=' "$test_root/running" || fail "$shell: a running shell was changed"
	[[ -z "${ASDF_PYTHON_VERSION:-}" ]] || fail "$shell: the calling process was changed"

	# Other commands keep their routing.
	[[ "$(run_shell "$shell" 'asdf current python')" == 'NATIVE: current python' ]] || fail "$shell: native routing changed"
	[[ "$(run_shell "$shell" 'asdf shellx python')" == 'NATIVE: shellx python' ]] || fail "$shell: shell prefix captured another command"
	[[ "$(run_shell "$shell" "$native_command shell python 1.0.0")" == 'NATIVE: shell python 1.0.0' ]] || fail "$shell: native asdf was wrapped"

	# Help is shown without changing anything.
	run_shell "$shell" 'asdf shell --help' >"$test_root/long"
	grep -q 'asdf-extras shell' "$test_root/long" || fail "$shell: asdf shell --help"
	run_shell "$shell" 'asdf shell -h' >"$test_root/short"
	cmp "$test_root/long" "$test_root/short"
	run_shell "$shell" "$(printf '%s\n' "asdf shell python 3.14.0 --help" "$external")" >"$test_root/position"
	head -n "$(($(wc -l <"$test_root/long")))" "$test_root/position" | cmp - "$test_root/long"
	! grep -q '^ASDF_PYTHON_VERSION=' "$test_root/position" || fail "$shell: help changed the override"
done

# A separate process cannot change the calling shell: it explains and fails.
for command_path in "$entry" "$repo_dir/lib/commands/command-shell"; do
	for args in "python 3.14.0" "--unset python" ""; do
		# shellcheck disable=SC2086
		if bash "$command_path" shell $args >"$test_root/output" 2>"$test_root/error"; then
			fail "standalone shell reported success"
		fi
		[[ ! -s "$test_root/output" ]] || fail "standalone shell printed output"
		grep -q 'initialized shell' "$test_root/error" || fail "standalone shell did not explain initialization"
	done
done
bash "$entry" shell --help >"$test_root/long"
bash "$entry" help shell >"$test_root/topic"
cmp "$test_root/long" "$test_root/topic"
grep -q 'asdf shell --unset' "$test_root/long" || fail "shell help lacks --unset"
bash "$repo_dir/lib/commands/command-shell" --help >"$test_root/plugin"
cmp "$test_root/long" "$test_root/plugin"
bash "$entry" help >"$test_root/summary"
grep -q 'asdf shell' "$test_root/summary" || fail "shell missing from help"

printf 'shell command tests: PASS\n'

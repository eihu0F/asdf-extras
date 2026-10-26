#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
native_asdf="$(command -v asdf || :)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export ASDF_HELP_REPO="$repo_dir"
export ASDF_HELP_ROOT="$test_root"
export PATH="$test_root/bin:$PATH"
mkdir -p "$test_root/bin"
cat >"$test_root/bin/asdf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Stand in for the two stable entry points that initialized wrappers use.
if [[ "${1:-}" == exec && "${2:-}" == asdf-extras ]]; then
	shift 2
	exec bash "$ASDF_HELP_REPO/libexec/asdf-extras" "$@"
fi
if [[ "${1:-}" == cmd && "${2:-}" == asdf-extras ]]; then
	subcommand="$3"
	shift 3
	[[ "${1:-}" != -- ]] || shift
	exec bash "$ASDF_HELP_REPO/lib/commands/command-$subcommand" "$@"
fi
printf '<%s>\n' "$@" >>"$ASDF_HELP_ROOT/native.log"
case "$*" in
"completion nushell")
	printf 'export extern asdf [...args: string]\nexport extern "asdf install" [...args: string]\nexport extern "asdf help" [...args: string]\n'
	;;
help | --help | -h)
	printf 'NATIVE HELP\nasdf install <plugin> <version>\n'
	if [[ "${ASDF_HELP_FAILURE:-}" == yes ]]; then
		printf 'native help failed\n' >&2
		exit 17
	fi
	;;
"install --help")
	printf 'NATIVE INSTALL HELP\nasdf install --keep-download\n'
	if [[ "${ASDF_HELP_FAILURE:-}" == yes ]]; then
		printf 'native help failed\n' >&2
		exit 17
	fi
	;;
"help nodejs" | "help install" | "help update" | "help install extra")
	printf 'NATIVE PLUGIN HELP: %s\n' "$*"
	;;
"help missing")
	printf 'native plugin help failed\n' >&2
	exit 23
	;;
*) printf 'NATIVE: %s\n' "$*" ;;
esac
EOF
chmod +x "$test_root/bin/asdf"
fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

entry="$repo_dir/libexec/asdf-extras"
bash "$entry" >"$test_root/direct"
grep -q 'init <bash|zsh|fish|elvish|nushell>' "$test_root/direct"
for topic in install update prune completion; do
	bash "$entry" help "$topic" >"$test_root/direct"
	bash "$entry" --help "$topic" >"$test_root/alias"
	cmp "$test_root/direct" "$test_root/alias"
	grep -q "asdf-extras $topic" "$test_root/direct"
	for flag in --help -h; do
		bash "$entry" "$topic" "$flag" >"$test_root/alias"
		cmp "$test_root/direct" "$test_root/alias"
		bash "$entry" "$topic" --local nodejs "$flag" >"$test_root/alias"
		cmp "$test_root/direct" "$test_root/alias"
	done
done
if bash "$entry" help unknown >"$test_root/direct" 2>"$test_root/error"; then
	fail 'unknown standalone topic accepted'
fi
grep -q 'unknown help topic' "$test_root/error"

if [[ -n "$native_asdf" ]]; then
	mkdir -p "$test_root/data/plugins"
	ln -s "$repo_dir" "$test_root/data/plugins/asdf-extras"
	for topic in install update completion; do
		ASDF_DATA_DIR="$test_root/data" "$native_asdf" cmd asdf-extras help "$topic" >"$test_root/plugin"
		bash "$repo_dir/libexec/asdf-extras" "$topic" --help >"$test_root/direct"
		cmp "$test_root/plugin" "$test_root/direct"
	done
fi
[[ "$(bash "$repo_dir/lib/extras/commands/__complete.bash" --standalone help u)" == update ]] ||
	fail 'standalone help topic completion missing'
grep -Fx prune < <(bash "$repo_dir/lib/extras/commands/__complete.bash" --standalone "") >/dev/null ||
	fail 'standalone prune completion missing'
[[ "$(bash "$repo_dir/lib/extras/commands/__complete.bash" --standalone help p)" == prune ]] ||
	fail 'prune help topic completion missing'

run_shell() {
	local shell="$1" request="$2" init_file
	case "$shell" in
	bash | zsh)
		init_file=bash.sh
		[[ "$shell" != zsh ]] || init_file=zsh.zsh
		printf "source \"\$ASDF_HELP_REPO/lib/init/%s\"\nsource \"\$ASDF_HELP_REPO/lib/init/%s\"\n%s\n" \
			"$init_file" "$init_file" "$request" >"$test_root/test"
		"$shell" "$test_root/test"
		;;
	fish)
		printf "source \"\$ASDF_HELP_REPO/lib/init/fish.fish\"\nsource \"\$ASDF_HELP_REPO/lib/init/fish.fish\"\n%s\n" "$request" >"$test_root/test"
		fish "$test_root/test"
		;;
	elvish)
		cat >"$test_root/test" <<'EOF'
var asdf~ = $nil
eval (e:cat $E:ASDF_HELP_REPO'/lib/init/elvish.elv' | slurp) &on-end={|ns| set asdf~ = $ns[asdf~]}
eval (e:cat $E:ASDF_HELP_REPO'/lib/init/elvish.elv' | slurp) &on-end={|ns| set asdf~ = $ns[asdf~]}
EOF
		printf '%s\n' "$request" >>"$test_root/test"
		elvish "$test_root/test"
		;;
	nushell)
		printf "source '%s/init.nu'\nsource '%s/init.nu'\n%s\nexit \$env.LAST_EXIT_CODE\n" \
			"$test_root" "$test_root" "$request" >"$test_root/test.nu"
		nu --no-config-file "$test_root/test.nu"
		;;
	esac
}

for origin in installed plugin; do
	export ASDF_EXTRAS_INIT_ORIGIN="$origin"
	for shell in bash zsh fish elvish nushell; do
		executable="$shell"
		[[ "$shell" != nushell ]] || executable=nu
		if ! command -v "$executable" >/dev/null; then
			printf 'SKIP: %s is unavailable\n' "$shell"
			continue
		fi
		if [[ "$shell" == nushell ]]; then
			if [[ "$origin" == installed ]]; then
				bash "$repo_dir/libexec/asdf-extras" init nushell >"$test_root/init.nu"
			else
				bash "$repo_dir/lib/commands/command-init" nushell >"$test_root/init.nu"
			fi
		fi
		case "$shell" in
		elvish) native_command=e:asdf ;;
		nushell) native_command='^asdf' ;;
		*) native_command='command asdf' ;;
		esac
		run_shell "$shell" "$native_command help" >"$test_root/native"
		! grep -q asdf-extras "$test_root/native" || fail 'plain asdf help was extended'
		for request in 'asdf help' 'asdf --help' 'asdf -h'; do
			run_shell "$shell" "$request" >"$test_root/output"
			grep -q 'NATIVE HELP' "$test_root/output"
			head -n 2 "$test_root/output" >"$test_root/prefix"
			cmp "$test_root/native" "$test_root/prefix"
			[[ "$(grep -c 'asdf-extras extensions' "$test_root/output")" == 1 ]] || fail 'stacked help'
		done
		run_shell "$shell" "$native_command install --help" >"$test_root/native"
		run_shell "$shell" 'asdf install --help' >"$test_root/output"
		grep -q 'NATIVE INSTALL HELP' "$test_root/output"
		head -n 2 "$test_root/output" >"$test_root/prefix"
		cmp "$test_root/native" "$test_root/prefix"
		grep -q 'asdf-extras install extensions' "$test_root/output"
		grep -q 'verifies activation' "$test_root/output"
		run_shell "$shell" 'asdf update --help' >"$test_root/output"
		grep -q 'update --all' "$test_root/output"
		grep -q 'cannot be resolved' "$test_root/output"
		grep -q 'Parent/local updates retain' "$test_root/output"
		for topic in install update completion; do
			run_shell "$shell" "asdf $topic --help" >"$test_root/long"
			run_shell "$shell" "asdf $topic -h" >"$test_root/short"
			cmp "$test_root/long" "$test_root/short"
			run_shell "$shell" "asdf $topic --local nodejs --help" >"$test_root/position"
			cmp "$test_root/long" "$test_root/position"
		done
		grep -q -- '--asdf adds' "$test_root/long"
		grep -q 'asdf-extras only' "$test_root/long"
		for request in 'asdf help nodejs' 'asdf help install' 'asdf help update' 'asdf help install extra'; do
			run_shell "$shell" "$request" >"$test_root/output"
			[[ "$(cat "$test_root/output")" == "NATIVE PLUGIN HELP: ${request#asdf }" ]] || fail 'native help changed'
		done
		run_shell "$shell" 'asdf help "plugin with spaces" "version with spaces"' >"$test_root/output"
		[[ "$(tail -n 3 "$test_root/native.log")" == "$(printf '%s\n' '<help>' '<plugin with spaces>' '<version with spaces>')" ]] ||
			fail 'plugin help argument boundaries changed'
		if run_shell "$shell" 'asdf help missing' >"$test_root/output" 2>"$test_root/error"; then
			fail 'native plugin failure suppressed'
		else
			rc=$?
			if run_shell "$shell" "$native_command help missing" >"$test_root/native" 2>"$test_root/native-error"; then
				fail 'native failure fixture succeeded'
			else
				[[ "$rc" -eq "$?" ]] || fail "native plugin failure status changed: $shell ($rc)"
			fi
		fi
		grep -q 'native plugin help failed' "$test_root/error"
		for request in 'asdf help' 'asdf install --help'; do
			if ASDF_HELP_FAILURE=yes run_shell "$shell" "$request" >"$test_root/output" 2>"$test_root/error"; then
				fail 'native help failure suppressed'
			else
				rc=$?
				if ASDF_HELP_FAILURE=yes run_shell "$shell" "$native_command help" >"$test_root/native" 2>"$test_root/native-error"; then
					fail 'native help failure fixture succeeded'
				else
					[[ "$rc" -eq "$?" ]] || fail "native help failure status changed: $shell ($rc)"
				fi
			fi
			! grep -q asdf-extras "$test_root/output" || fail 'extras appended after native failure'
			grep -q 'native help failed' "$test_root/error"
		done
		printf '%s help routing (%s): PASS\n' "$shell" "$origin"
	done
done
printf 'help regression tests: PASS\n'

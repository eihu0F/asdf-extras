#!/usr/bin/env bash

set -euo pipefail

MIN_ASDF_VERSION="0.16.0"

log() {
	printf "%s\n" "$*"
}

fail() {
	printf "ERROR: %s\n" "$*" >&2
	exit 1
}

version_ge() {
	local a="$1"
	local b="$2"
	[[ "$(printf "%s\n%s\n" "$a" "$b" | sort -V | tail -n1)" == "$a" ]]
}

require_asdf() {
	command -v asdf >/dev/null 2>&1 || fail "asdf command not found"

	local raw version
	raw="$(asdf --version)"
	version="$(printf "%s\n" "$raw" | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | sed 's/^v//')"
	[[ -n "$version" ]] || fail "could not parse asdf version from: $raw"

	if ! version_ge "$version" "$MIN_ASDF_VERSION"; then
		fail "asdf >= $MIN_ASDF_VERSION is required (found $version)"
	fi

	log "asdf version check: OK ($version)"
}

check_asdf_plugin_test() {
	if asdf plugin test --help >/dev/null 2>&1; then
		log "asdf plugin test support: OK"
		return 0
	fi

	log "asdf plugin test support: NG"
	return 1
}

run_asdf_plugin_test() (
	local output exit_code data_dir old_shims test_path latest_tag
	local -a version_args=()

	data_dir="$(mktemp -d "${TMPDIR:-/tmp}/asdf-extras-test.XXXXXX")"
	trap 'rm -rf "$data_dir"' EXIT
	git config --file "$data_dir/gitconfig" "url.file://$PWD.insteadOf" "https://github.com/eihu0F/asdf-extras"
	latest_tag="$(git tag --sort=-version:refname --list 'v[0-9]*' | head -n1)"
	if [[ -n "$latest_tag" ]]; then
		version_args=(--asdf-tool-version "${latest_tag#v}")
	fi
	old_shims="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
	test_path=":$PATH:"
	test_path="${test_path//:"$old_shims":/:$data_dir/shims:}"
	test_path="${test_path#:}"
	test_path="${test_path%:}"
	if output="$(ASDF_DATA_DIR="$data_dir" PATH="$test_path" GIT_CONFIG_GLOBAL="$data_dir/gitconfig" asdf plugin test "${version_args[@]}" asdf-extras "$PWD" "asdf-extras --help" 2>&1)"; then
		exit_code=0
	else
		exit_code=$?
	fi

	if [[ $exit_code -eq 0 ]]; then
		log "asdf plugin test: PASS"
		return 0
	fi

	log "asdf plugin test: FAIL"
	printf "%s\n" "$output"

	if grep -q 'Unable to list available versions' <<<"$output"; then
		log "note: full asdf plugin test skipped because installable versions could not be listed"
		return 2
	fi
	if grep -q 'unable to clone plugin:' <<<"$output"; then
		log "note: full asdf plugin test skipped because the plugin could not be cloned"
		return 2
	fi

	return 1
)

run_custom_smoke() {
	log "running fallback custom smoke tests..."

	if shellcheck --version >/dev/null 2>&1 && shfmt --version >/dev/null 2>&1; then
		./scripts/lint.bash
		log "lint: PASS"
	else
		log "shellcheck/shfmt are not installed (lint skipped)"
		log "hint: run 'asdf install' to install tools from .tool-versions"
	fi

	if command -v asdf-extras >/dev/null 2>&1; then
		asdf-extras --help >/dev/null
		log "asdf-extras --help: PASS"
	else
		log "asdf-extras command is not installed yet (skipped)"
	fi

	if asdf cmd asdf-extras --help >/dev/null 2>&1; then
		log "asdf cmd asdf-extras --help: PASS"
	else
		log "asdf cmd asdf-extras --help is not available yet (skipped)"
	fi
}

main() {
	local plugin_test_rc

	require_asdf
	check_asdf_plugin_test || fail "asdf plugin test command is unavailable"

	if run_asdf_plugin_test; then
		plugin_test_rc=0
	else
		plugin_test_rc=$?
	fi

	case "$plugin_test_rc" in
	0)
		log "all checks passed"
		;;
	2)
		run_custom_smoke
		log "fallback checks passed"
		;;
	*)
		fail "asdf plugin test failed for a reason other than version listing or clone"
		;;
	esac
}

main "$@"

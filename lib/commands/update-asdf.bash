#!/usr/bin/env bash

set -euo pipefail

fail() {
	printf 'asdf-extras: %s\n' "$*" >&2
	exit 1
}

parse_version() {
	local pattern='^(asdf version )?v?([0-9]+\.[0-9]+\.[0-9]+)([[:space:]].*)?$'
	[[ "$1" != *$'\n'* && "$1" =~ $pattern ]] || return 1
	printf '%s\n' "${BASH_REMATCH[2]}"
}

asdf_bin="$(type -P asdf)" || fail "asdf executable not found"
asdf_bin="$(cd "$(dirname "$asdf_bin")" && pwd -P)/$(basename "$asdf_bin")"
script="${ASDF_DATA_DIR:-$HOME/.asdf}/asdf-extras/update-asdf.bash"

if [[ -e "$script" ]]; then
	[[ -f "$script" && -r "$script" ]] || fail "update script is not a readable file: $script"
	printf 'asdf-extras: running update script: %s\n' "$script"
	if ! "$BASH" "$script" "$asdf_bin"; then
		fail "asdf update script failed: $script"
	fi
	exit 0
fi

# Resolve symlinks only to identify Homebrew; never overwrite other symlink targets.
resolved="$asdf_bin"
links=0
while [[ -L "$resolved" ]]; do
	((links < 40)) || fail "too many symlinks resolving asdf"
	links=$((links + 1))
	link="$(readlink "$resolved")"
	case "$link" in
	/*) resolved="$link" ;;
	*) resolved="$(dirname "$resolved")/$link" ;;
	esac
	resolved="$(cd "$(dirname "$resolved")" && pwd -P)/$(basename "$resolved")"
done

if command -v brew >/dev/null 2>&1; then
	cellar="$(command brew --cellar asdf 2>/dev/null)" || cellar=""
	if [[ -n "$cellar" && "$resolved" == "$cellar/"* ]]; then
		printf 'asdf-extras: updating Homebrew-managed asdf\n'
		if ! (command brew upgrade asdf); then
			fail "Homebrew asdf update failed"
		fi
		exit 0
	fi
fi

home_dir="$(cd "$HOME" && pwd -P)"
case "$asdf_bin" in
"$home_dir"/*) ;;
*) fail "cannot safely replace asdf at $asdf_bin; provide $script for your installation method" ;;
esac
[[ ! -L "$asdf_bin" && -f "$asdf_bin" && -O "$asdf_bin" ]] ||
	fail "asdf is not an owned standalone file; provide $script"
[[ -w "$asdf_bin" && -w "$(dirname "$asdf_bin")" ]] ||
	fail "asdf installation is not writable: $asdf_bin; provide $script"
magic="$(od -An -tx1 -N4 "$asdf_bin" | tr -d ' \n')"
case "$magic" in
7f454c46 | feedface | cefaedfe | feedfacf | cffaedfe | cafebabe | bebafeca | cafebabf | bfbafeca) ;;
*) fail "asdf is not a native standalone binary (it may be a shim); provide $script" ;;
esac
command -v jq >/dev/null 2>&1 || fail "jq is required for standalone asdf updates; install jq or provide $script"

case "$(uname -s)" in
Darwin) os=darwin ;;
Linux) os=linux ;;
*) fail "unsupported operating system; provide $script" ;;
esac
case "$(uname -m)" in
x86_64 | amd64) arch=amd64 ;;
arm64 | aarch64) arch=arm64 ;;
i386 | i686) arch=386 ;;
*) fail "unsupported architecture; provide $script" ;;
esac

stage="$(mktemp -d "$(dirname "$asdf_bin")/.asdf-update.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
	https://api.github.com/repos/asdf-vm/asdf/releases/latest -o "$stage/release.json" ||
	fail "could not fetch asdf release metadata"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' "$stage/release.json")" ||
	fail "could not determine the latest stable asdf release"
current="$("$asdf_bin" --version)" || fail "could not determine the installed asdf version"
current="$(parse_version "$current")" || fail "unrecognized installed asdf version"
if ! awk -v old="$current" -v new="${tag#v}" 'BEGIN {
	split(old,a,"."); split(new,b,".");
	for (i=1;i<=3;i++) {if (b[i]+0>a[i]+0) exit 0; if (b[i]+0<a[i]+0) exit 1}
	exit 1
}'; then
	printf 'asdf-extras: asdf is already current (%s)\n' "$current"
	exit 0
fi
asset="asdf-${tag}-${os}-${arch}.tar.gz"
digest="$(jq -er --arg name "$asset" \
	'.assets[] | select(.name == $name) | .digest | select(test("^sha256:[0-9a-f]{64}$"))' \
	"$stage/release.json")" || fail "release has no SHA-256 digest for $asset"
curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
	"https://github.com/asdf-vm/asdf/releases/download/${tag}/${asset}" -o "$stage/release.tar.gz" ||
	fail "could not download asdf release archive"
if command -v sha256sum >/dev/null 2>&1; then
	actual="$(sha256sum "$stage/release.tar.gz")"
else
	actual="$(shasum -a 256 "$stage/release.tar.gz")"
fi
[[ "${actual%% *}" == "${digest#sha256:}" ]] || fail "asdf archive SHA-256 verification failed"
tar -xOf "$stage/release.tar.gz" asdf >"$stage/asdf"
chmod +x "$stage/asdf"
candidate="$("$stage/asdf" --version)" || fail "downloaded asdf executable failed validation"
candidate="$(parse_version "$candidate")" || fail "unrecognized downloaded asdf version"
[[ "$candidate" == "${tag#v}" ]] ||
	fail "downloaded asdf version does not match $tag"

# Same-filesystem rename replaces the executable only after full validation.
mv -f "$stage/asdf" "$asdf_bin"
printf 'asdf-extras: updated asdf from %s to %s\n' "$current" "$tag"

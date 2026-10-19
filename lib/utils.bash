#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/eihu0F/asdf-extras"
TOOL_NAME="asdf-extras"
TOOL_TEST="asdf-extras --help"

fail() {
	echo -e "$TOOL_NAME: $*"
	exit 1
}

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	local versions
	versions="$(list_github_tags)"
	if [[ -n "$versions" ]]; then
		printf "%s\n" "$versions"
		return 0
	fi

	# Fallback for repositories without release tags yet.
	printf "%s\n" "main"
}

resolve_checkout_ref() {
	local repo_dir version
	repo_dir="$1"
	version="$2"

	for ref in "refs/tags/v${version}" "refs/tags/${version}" "${version}"; do
		if git -C "$repo_dir" rev-parse -q --verify "$ref" >/dev/null 2>&1; then
			printf "%s\n" "$ref"
			return 0
		fi
	done

	fail "Could not resolve checkout ref for version: $version"
}

download_release() {
	local repo_dir version destination ref
	repo_dir="$1"
	version="$2"
	destination="$3"

	ref="$(resolve_checkout_ref "$repo_dir" "$version")"
	echo "* Exporting $TOOL_NAME from local checkout ref $ref..."
	git -C "$repo_dir" archive --format=tar "$ref" | tar -xf - -C "$destination" || fail "Could not export ref: $ref"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_root="${3%/bin}"
	local install_path="${install_root}/bin"
	local runtime_path="${install_root}/lib/${TOOL_NAME}"

	if [ "$install_type" != "version" ]; then
		fail "$TOOL_NAME supports release installs only"
	fi

	(
		rm -rf "$runtime_path"
		mkdir -p "$install_path"
		mkdir -p "$runtime_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$runtime_path"

		cat >"$install_path/$TOOL_NAME" <<-EOF
			#!/usr/bin/env bash
			set -euo pipefail
			exec "$runtime_path/libexec/asdf-extras" "\$@"
		EOF
		chmod +x "$install_path/$TOOL_NAME"

		chmod +x "$runtime_path/libexec/asdf-extras"
		chmod +x "$runtime_path/lib/commands/command-help"
		chmod +x "$runtime_path/lib/commands/command-init"
		chmod +x "$runtime_path/lib/commands/command-install"
		chmod +x "$runtime_path/lib/commands/command-update"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "${install_path:?}/$TOOL_NAME" "${runtime_path:?}"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}

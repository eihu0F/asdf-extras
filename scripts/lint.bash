#!/usr/bin/env bash

shellcheck --shell=bash --external-sources \
	bin/* \
	lib/utils.bash \
	lib/commands/* --source-path=lib/commands/ \
	lib/completion/*.bash \
	libexec/* \
	scripts/*

# Without globstar, ./**/* expands to ./*/*; skip docs, which hold Markdown.
shell_files=()
for path in ./*/*; do
	[[ "$path" == ./docs/* ]] || shell_files+=("$path")
done

shfmt --language-dialect bash --diff \
	"${shell_files[@]}"

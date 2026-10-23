#!/usr/bin/env bash

# Without globstar, ./**/* expands to ./*/*; skip docs, which hold Markdown.
shell_files=()
for path in ./*/*; do
	[[ "$path" == ./docs/* ]] || shell_files+=("$path")
done

shfmt --language-dialect bash --write \
	"${shell_files[@]}"

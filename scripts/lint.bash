#!/usr/bin/env bash

shellcheck --shell=bash --external-sources \
	bin/* \
	lib/utils.bash \
	lib/commands/* --source-path=lib/commands/ \
	lib/completion/*.bash \
	libexec/* \
	scripts/*

shfmt --language-dialect bash --diff \
	./**/*

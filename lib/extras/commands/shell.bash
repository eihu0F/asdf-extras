#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
extras_lib=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

# shellcheck source=../help.bash
source "${extras_lib}/help.bash"
extras_maybe_help shell "$@"

# A child process cannot change its parent's environment, so the session
# override lives in the initialized asdf wrapper. Never report success here.
extras_fail "shell must run through an initialized shell; a separate process cannot change the calling shell (see: asdf-extras init <shell>, then: asdf shell <plugin> <version>)"

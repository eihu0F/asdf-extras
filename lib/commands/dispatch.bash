#!/usr/bin/env bash

set -euo pipefail

# Initialized shell wrappers route extended commands to the installed runtime.
exec bash "$(dirname "${BASH_SOURCE[0]}")/../extras/dispatch.bash" installed "$@"

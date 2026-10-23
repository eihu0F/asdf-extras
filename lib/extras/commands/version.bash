#!/usr/bin/env bash

set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
extras_lib=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=../common.bash
source "${extras_lib}/common.bash"

extras_self_version

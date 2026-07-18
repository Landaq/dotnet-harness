#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
source "$script_dir/assets/harness/.codex/scripts/python-env.zsh"
resolve_dotnet_harness_python

exec "$DOTNET_HARNESS_PYTHON" "$script_dir/install.py" "$@"

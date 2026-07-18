#!/usr/bin/env zsh

script_dir="${0:A:h}"
source "$script_dir/python-env.zsh"
resolve_dotnet_harness_python

exec "$DOTNET_HARNESS_PYTHON" "$script_dir/upgrade_harness.py" "$@"

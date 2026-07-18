#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
plugin_root=${script_dir:h}
source "$plugin_root/assets/harness/.codex/scripts/python-env.zsh"
resolve_dotnet_harness_python

core="$script_dir/validation/validate_release.py"
requirements="$script_dir/validation/requirements.txt"

mode=Quick
for (( index = 1; index <= $#; index++ )); do
  if [[ ${argv[index]} == --mode && index -lt $# ]]; then
    mode=${argv[index + 1]}
  elif [[ ${argv[index]} == --mode=* ]]; then
    mode=${argv[index]#--mode=}
  fi
done

case ${mode:l} in
  harness|scaffold|upgrade|whitespace)
    exec "$DOTNET_HARNESS_PYTHON" "$core" --plugin-root "$plugin_root" "$@"
    ;;
esac

if "$DOTNET_HARNESS_PYTHON" -c 'import yaml' 2>/dev/null; then
  exec "$DOTNET_HARNESS_PYTHON" "$core" --plugin-root "$plugin_root" "$@"
fi

if (( ! $+commands[uv] )); then
  print -u2 "PyYAML is required for release validation."
  print -u2 "Install uv with 'brew install uv', then rerun this command."
  exit 1
fi

export UV_CACHE_DIR=${UV_CACHE_DIR:-${TMPDIR:-/tmp}/dotnet-harness-uv-cache}
exec "${commands[uv]}" run --no-project --python "$DOTNET_HARNESS_PYTHON" \
  --with-requirements "$requirements" -- python "$core" --plugin-root "$plugin_root" "$@"

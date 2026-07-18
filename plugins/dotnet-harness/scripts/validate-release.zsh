#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
plugin_root=${script_dir:h}

mode=Quick
browser_e2e=false
for (( index = 1; index <= $#; index++ )); do
  if [[ ${argv[index]} == --mode ]]; then
    if (( index == $# )); then
      print -u2 "Missing value for --mode"
      exit 2
    fi
    mode=${argv[index + 1]}
    (( index++ ))
  elif [[ ${argv[index]} == --mode=* ]]; then
    mode=${argv[index]#--mode=}
  elif [[ ${argv[index]} == --browser-e2e ]]; then
    browser_e2e=true
  fi
done

case ${mode:l} in
  quick|full|core|harness|scaffold|upgrade|whitespace)
    ;;
  *)
    print -u2 "Invalid validation mode: $mode"
    print -u2 "Expected one of: Quick, Full, Core, Harness, Scaffold, Upgrade, Whitespace"
    exit 2
    ;;
esac

source "$plugin_root/assets/harness/.codex/scripts/python-env.zsh"
resolve_dotnet_harness_python

core="$script_dir/validation/validate_release.py"
requirements="$script_dir/validation/requirements.txt"

needs_yaml=false
needs_playwright=false
case ${mode:l} in
  quick|full|core)
    needs_yaml=true
    ;;
esac
if [[ ${mode:l} == full || $browser_e2e == true ]]; then
  needs_playwright=true
fi

if [[ $needs_yaml == false && $needs_playwright == false ]]; then
    exec "$DOTNET_HARNESS_PYTHON" "$core" --plugin-root "$plugin_root" "$@"
fi

imports=""
if [[ $needs_yaml == true ]]; then
  imports="import yaml"
fi
if [[ $needs_playwright == true ]]; then
  if [[ -n $imports ]]; then
    imports+="; import playwright"
  else
    imports="import playwright"
  fi
fi

if "$DOTNET_HARNESS_PYTHON" -c "$imports" 2>/dev/null; then
  exec "$DOTNET_HARNESS_PYTHON" "$core" --plugin-root "$plugin_root" "$@"
fi

if (( ! $+commands[uv] )); then
  print -u2 "Release validation dependencies are missing."
  print -u2 "Install uv with 'brew install uv', then rerun this command."
  exit 1
fi

export UV_CACHE_DIR=${UV_CACHE_DIR:-${TMPDIR:-/tmp}/dotnet-harness-uv-cache}
exec "${commands[uv]}" run --no-project --python "$DOTNET_HARNESS_PYTHON" \
  --with-requirements "$requirements" -- python "$core" --plugin-root "$plugin_root" "$@"

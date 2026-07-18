#!/bin/zsh

resolve_dotnet_harness_python() {
  local candidate
  local -a candidates

  if [[ -n ${DOTNET_HARNESS_PYTHON:-} ]]; then
    candidates+=("$DOTNET_HARNESS_PYTHON")
  fi

  for candidate in python3.13 python3.12 python3.11 python3; do
    if (( $+commands[$candidate] )); then
      candidates+=("${commands[$candidate]}")
    fi
  done

  candidates+=(
    /opt/homebrew/bin/python3
    /usr/local/bin/python3
    "$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3.12"
  )

  for candidate in $candidates; do
    if [[ -x $candidate ]] && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
      export DOTNET_HARNESS_PYTHON=$candidate
      return 0
    fi
  done

  print -u2 "dotnet-harness requires Python 3.11 or newer."
  print -u2 "Install it with 'brew install python@3.12' or set DOTNET_HARNESS_PYTHON."
  return 1
}

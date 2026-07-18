#!/usr/bin/env zsh

set -eu

repo_root="$PWD"

while (( $# > 0 )); do
  case "$1" in
    --repo-root)
      if (( $# < 2 )); then
        print -u2 "Missing value for --repo-root."
        exit 2
      fi
      repo_root="$2"
      shift 2
      ;;
    -h|--help)
      print "Usage: ${0:t} [--repo-root <path>]"
      exit 0
      ;;
    *)
      print -u2 "Unknown argument: $1"
      print -u2 "Usage: ${0:t} [--repo-root <path>]"
      exit 2
      ;;
  esac
done

script_dir="${0:A:h}"
source "$script_dir/python-env.zsh"
resolve_dotnet_harness_python

exec "$DOTNET_HARNESS_PYTHON" "$script_dir/validate_task_agents.py" --repo-root "$repo_root"

#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def require_supported_python() -> None:
    if sys.version_info < (3, 11):
        raise SystemExit(
            "dotnet-harness requires Python 3.11 or newer; "
            f"current interpreter is {sys.version.split()[0]}"
        )


def existing_harness(root: Path) -> bool:
    return any(
        (root / relative).exists()
        for relative in ("AGENTS.md", ".codex/agents", ".codex/scripts", ".codex/skills")
    )


def run_checked(command: list[str]) -> None:
    completed = subprocess.run(command, check=False)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Install the dotnet-harness project structure and Codex harness")
    parser.add_argument("--root", default=".")
    parser.add_argument("--project-name")
    parser.add_argument("--service-name")
    parser.add_argument("--no-service", action="store_true")
    parser.add_argument("--harness-only", action="store_true")
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--no-gitkeep", action="store_true")
    parser.add_argument("--skip-harness-upgrade", action="store_true")
    return parser.parse_args()


def main() -> int:
    require_supported_python()
    args = parse_args()

    plugin_root = Path(__file__).resolve().parent
    target_root = Path(args.root).expanduser().resolve()
    bootstrap = plugin_root / "skills/project-structure-setup/scripts/bootstrap_project_structure.py"
    upgrade = plugin_root / "assets/harness/.codex/scripts/upgrade_harness.py"
    harness_source = plugin_root / "assets/harness"

    if not bootstrap.is_file():
        raise SystemExit(f"Missing bootstrap script: {bootstrap}")

    if not args.skip_harness_upgrade and existing_harness(target_root):
        if not upgrade.is_file():
            raise SystemExit(f"Missing harness upgrade core: {upgrade}")

        upgrade_command = [
            sys.executable,
            str(upgrade),
            "--target-root",
            str(target_root),
            "--source-root",
            str(harness_source),
        ]
        if not args.preview:
            upgrade_command.append("--apply")

        print(f"[upgrade] existing repo-local harness detected: {target_root}")
        run_checked(upgrade_command)
        if args.harness_only:
            return 0

    bootstrap_command = [sys.executable, str(bootstrap), "--root", str(target_root)]
    if args.project_name:
        bootstrap_command.extend(("--project-name", args.project_name))
    if args.service_name:
        bootstrap_command.extend(("--service-name", args.service_name))
    if args.no_service:
        bootstrap_command.append("--no-service")
    if args.harness_only:
        bootstrap_command.append("--harness-only")
    if args.preview:
        bootstrap_command.append("--preview")
    if args.no_gitkeep:
        bootstrap_command.append("--no-gitkeep")

    run_checked(bootstrap_command)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

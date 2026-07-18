#!/usr/bin/env python3
"""Upgrade a project's installed dotnet-harness files."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time


class UpgradeError(RuntimeError):
    """An expected harness upgrade failure."""


def full_path(value: str | Path) -> Path:
    return Path(value).expanduser().resolve(strict=False)


def default_source_root() -> Path:
    return Path(__file__).resolve().parents[2]


def assert_harness_source(root: Path) -> None:
    for relative in (Path("AGENTS.md"), Path(".codex/agents"), Path(".codex/scripts")):
        path = root / relative
        if not path.exists():
            raise UpgradeError(f"Invalid harness source. Missing: {path}")


def copy_existing_to_backup(target: Path, backup_root: Path) -> None:
    backup_items = (
        (Path("AGENTS.md"), Path("AGENTS.md")),
        (Path(".codex/agents"), Path("agents-backup")),
        (Path(".codex/skills"), Path("skills-backup")),
        (Path(".codex/scripts"), Path("scripts-backup")),
    )

    for relative, backup_relative in backup_items:
        source = target / relative
        if not source.exists():
            continue

        backup = backup_root / backup_relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, backup, dirs_exist_ok=True)
        else:
            shutil.copy2(source, backup)
        print(f"[backup] {source} -> {backup}")


def move_to_backup_file(path: Path) -> None:
    destination = path.with_name(f"{path.name}.bak")
    if destination.exists():
        destination = path.with_name(f"{path.name}.{time.time_ns() // 1_000_000}.bak")

    path.replace(destination)
    print(f"[protect] {path} -> {destination}")


def is_below_named_directory(path: Path, directory_name: str) -> bool:
    expected = directory_name.casefold()
    return any(part.casefold() == expected for part in path.parent.parts)


def is_below_codex_directory(path: Path, child: str) -> bool:
    parts = tuple(part.casefold() for part in path.parent.parts)
    expected_child = child.casefold()
    return any(
        parts[index] == ".codex" and parts[index + 1] == expected_child
        for index in range(len(parts) - 1)
    )


def protect_backup_from_discovery(backups_root: Path) -> None:
    if not backups_root.exists():
        return

    backup_files = tuple(path for path in backups_root.rglob("*") if path.is_file())
    for path in backup_files:
        is_agent = path.suffix.casefold() == ".toml" and (
            is_below_named_directory(path, "agents-backup")
            or is_below_codex_directory(path, "agents")
        )
        is_skill = path.name.casefold() == "skill.md" and (
            is_below_named_directory(path, "skills-backup")
            or is_below_codex_directory(path, "skills")
        )
        if is_agent or is_skill:
            move_to_backup_file(path)


def remove_path(path: Path) -> None:
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif path.exists() or path.is_symlink():
        path.unlink()


def replace_tree(source: Path, target: Path) -> None:
    if target.exists() or target.is_symlink():
        remove_path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, target)


def copy_harness_to_target(source: Path, target: Path) -> None:
    for relative in (Path(".gitignore"), Path(".gitattributes"), Path(".codex/harness-config.json")):
        source_path = source / relative
        target_path = target / relative
        if source_path.exists() and not target_path.exists():
            target_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_path, target_path)
            print(f"[create] {target_path}")
        elif target_path.exists():
            print(f"[skip] exists: {target_path}")

    source_agents = source / "AGENTS.md"
    target_agents = target / "AGENTS.md"
    target_agents.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_agents, target_agents)
    print(f"[update] {target_agents}")

    for relative in (Path(".codex/agents"), Path(".codex/scripts")):
        source_path = source / relative
        target_path = target / relative
        replace_tree(source_path, target_path)
        print(f"[replace] {target_path}")

    skills_target = target / ".codex/skills"
    if skills_target.exists() or skills_target.is_symlink():
        remove_path(skills_target)
        print(f"[remove] {skills_target}")


def write_preview(source: Path, target: Path) -> None:
    print("Preview only. Re-run with the platform apply flag to backup and update the target harness.")
    for relative in (Path(".gitignore"), Path(".gitattributes"), Path(".codex/harness-config.json")):
        source_path = source / relative
        target_path = target / relative
        if source_path.exists() and not target_path.exists():
            print(f"[preview] create {target_path}")
        elif target_path.exists():
            print(f"[preview] skip existing {target_path}")

    print("[preview] backup AGENTS.md, .codex\\agents, .codex\\skills, .codex\\scripts")
    print("[preview] replace active .codex\\agents with source harness agents")
    print("[preview] remove active .codex\\skills after backup; plugin skills remain the source")
    print("[preview] replace active .codex\\scripts with source harness scripts")
    print("[preview] backup agent .toml files and skill SKILL.md files are renamed to .bak to avoid active discovery")


def run_validation(target: Path, backup_root: Path) -> None:
    scripts_root = target / ".codex/scripts"
    if os.name == "nt" or platform.system() == "Windows":
        validator = scripts_root / "validate-task-agents.ps1"
        command = ("pwsh", "-NoProfile", "-File", str(validator), "-RepoRoot", str(target))
    else:
        validator = scripts_root / "validate-task-agents.zsh"
        command = ("zsh", str(validator), "--repo-root", str(target))

    if not validator.exists():
        return

    try:
        sys.stdout.flush()
        result = subprocess.run(command, check=False)
    except OSError as error:
        raise UpgradeError(
            f"Harness validation failed after upgrade. Backup: {backup_root} ({error})"
        ) from error
    if result.returncode != 0:
        raise UpgradeError(f"Harness validation failed after upgrade. Backup: {backup_root}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-root", default=os.getcwd())
    parser.add_argument("--source-root")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--skip-validation", action="store_true")
    return parser.parse_args(argv)


def upgrade(args: argparse.Namespace) -> None:
    target = full_path(args.target_root)
    source = full_path(args.source_root) if args.source_root else default_source_root()
    assert_harness_source(source)

    print(f"Harness source: {source}")
    print(f"Target project: {target}")

    if not args.apply:
        write_preview(source, target)
        return

    target.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime())
    backup_root = target / ".codex/backups" / f"harness-upgrade-{stamp}"
    backup_root.mkdir(parents=True, exist_ok=True)

    copy_existing_to_backup(target, backup_root)
    protect_backup_from_discovery(target / ".codex/backups")
    copy_harness_to_target(source, target)

    if not args.skip_validation:
        run_validation(target, backup_root)

    print(f"Harness upgrade complete. Backup: {backup_root}")


def main(argv: list[str] | None = None) -> int:
    try:
        upgrade(parse_args(sys.argv[1:] if argv is None else argv))
    except (UpgradeError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

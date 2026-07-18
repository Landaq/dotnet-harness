#!/usr/bin/env python3
"""Upgrade a project's installed dotnet-harness files."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time


class UpgradeError(RuntimeError):
    """An expected harness upgrade failure."""


MANAGED_PATHS = (
    Path(".gitignore"),
    Path(".gitattributes"),
    Path("AGENTS.md"),
    Path(".codex/harness-config.json"),
    Path(".codex/agent-categories"),
    Path(".codex/agents"),
    Path(".codex/skills"),
    Path(".codex/scripts"),
)


def full_path(value: str | Path) -> Path:
    return Path(value).expanduser().resolve(strict=False)


def default_source_root() -> Path:
    return Path(__file__).resolve().parents[2]


def assert_harness_source(root: Path) -> None:
    for relative in (
        Path("AGENTS.md"),
        Path(".codex/agent-categories"),
        Path(".codex/agents"),
        Path(".codex/scripts"),
    ):
        path = root / relative
        if not path.exists():
            raise UpgradeError(f"Invalid harness source. Missing: {path}")


def assert_safe_target_layout(target: Path) -> None:
    for path in (target / ".codex", target / ".codex/backups"):
        if path.is_symlink():
            raise UpgradeError(
                f"Refusing harness upgrade through a symlinked managed directory: {path}"
            )


@contextmanager
def upgrade_lock(target: Path):
    codex_root = target / ".codex"
    codex_root.mkdir(parents=True, exist_ok=True)
    lock_path = codex_root / ".harness-upgrade.lock"
    try:
        descriptor = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError as error:
        raise UpgradeError(
            f"Another harness upgrade is active or left an unresolved lock: {lock_path}"
        ) from error
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(f"pid={os.getpid()}\n")
        yield
    finally:
        try:
            lock_path.unlink()
        except FileNotFoundError:
            pass


def write_transaction_state(backup_root: Path, state: str, error: BaseException | None = None) -> None:
    payload = {"state": state}
    if error is not None:
        payload["error"] = str(error) or type(error).__name__
    state_path = backup_root / "transaction-state.json"
    state_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def copy_existing_to_backup(target: Path, backup_root: Path) -> None:
    backup_items = (
        (Path("AGENTS.md"), Path("AGENTS.md")),
        (Path(".codex/agent-categories"), Path("agent-categories-backup")),
        (Path(".codex/agents"), Path("agents-backup")),
        (Path(".codex/skills"), Path("skills-backup")),
        (Path(".codex/scripts"), Path("scripts-backup")),
    )

    for relative, backup_relative in backup_items:
        source = target / relative
        if not path_exists(source):
            continue

        backup = backup_root / backup_relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        copy_path(source, backup)
        print(f"[backup] {source} -> {backup}")


def path_exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def copy_path(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        target.symlink_to(os.readlink(source), target_is_directory=source.is_dir())
    elif source.is_dir():
        shutil.copytree(source, target, symlinks=True)
    else:
        shutil.copy2(source, target, follow_symlinks=False)


def create_rollback_snapshot(target: Path, snapshot_root: Path) -> dict[Path, Path | None]:
    snapshot: dict[Path, Path | None] = {}
    for index, relative in enumerate(MANAGED_PATHS):
        source = target / relative
        if not path_exists(source):
            snapshot[relative] = None
            continue

        saved = snapshot_root / f"item-{index:02d}"
        copy_path(source, saved)
        snapshot[relative] = saved
    return snapshot


def restore_rollback_snapshot(target: Path, snapshot: dict[Path, Path | None]) -> list[str]:
    failures: list[str] = []
    for relative, saved in snapshot.items():
        destination = target / relative
        try:
            if path_exists(destination):
                remove_path(destination)
            if saved is not None:
                copy_path(saved, destination)
            print(f"[rollback] restored {destination}")
        except Exception as error:
            failures.append(f"{destination}: {error}")
    return failures


def allocate_backup_root(target: Path) -> Path:
    backups_root = target / ".codex/backups"
    backups_root.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime())

    for sequence in range(1000):
        suffix = "" if sequence == 0 else f"-{sequence:03d}"
        backup_root = backups_root / f"harness-upgrade-{stamp}{suffix}"
        try:
            backup_root.mkdir()
        except FileExistsError:
            continue
        return backup_root

    raise UpgradeError(f"Could not allocate a unique harness backup below: {backups_root}")


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
    if path_exists(target_agents):
        remove_path(target_agents)
    target_agents.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_agents, target_agents)
    print(f"[update] {target_agents}")

    for relative in (
        Path(".codex/agent-categories"),
        Path(".codex/agents"),
        Path(".codex/scripts"),
    ):
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

    print(
        "[preview] backup AGENTS.md, .codex\\agent-categories, "
        ".codex\\agents, .codex\\skills, .codex\\scripts"
    )
    print("[preview] replace active .codex\\agent-categories with source catalog")
    print("[preview] replace active .codex\\agents with source harness agents")
    print("[preview] remove active .codex\\skills after backup; plugin skills remain the source")
    print("[preview] replace active .codex\\scripts with source harness scripts")
    print("[preview] backup agent .toml files and skill SKILL.md files are renamed to .bak to avoid active discovery")


def run_validation(target: Path, backup_root: Path) -> None:
    validator, command = validation_command(target)

    if not validator.is_file():
        raise UpgradeError(f"Harness validation requested but validator is missing: {validator}")

    try:
        sys.stdout.flush()
        result = subprocess.run(command, check=False)
    except OSError as error:
        raise UpgradeError(
            f"Harness validation failed after upgrade. Backup: {backup_root} ({error})"
        ) from error
    if result.returncode != 0:
        raise UpgradeError(f"Harness validation failed after upgrade. Backup: {backup_root}")


def validation_command(root: Path) -> tuple[Path, tuple[str, ...]]:
    scripts_root = root / ".codex/scripts"
    if os.name == "nt" or platform.system() == "Windows":
        validator = scripts_root / "validate-task-agents.ps1"
        command = ("pwsh", "-NoProfile", "-File", str(validator), "-RepoRoot", str(root))
    else:
        validator = scripts_root / "validate-task-agents.zsh"
        command = ("zsh", str(validator), "--repo-root", str(root))
    return validator, command


def assert_validator_source(source: Path) -> None:
    validator, _ = validation_command(source)
    if not validator.is_file():
        raise UpgradeError(f"Harness validation requested but source validator is missing: {validator}")


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

    assert_safe_target_layout(target)
    if not args.skip_validation:
        assert_validator_source(source)

    target.mkdir(parents=True, exist_ok=True)
    with upgrade_lock(target):
        backup_root = allocate_backup_root(target)
        write_transaction_state(backup_root, "applying")

        with tempfile.TemporaryDirectory(
            prefix="dotnet-harness-upgrade-", ignore_cleanup_errors=True
        ) as snapshot_directory:
            snapshot = create_rollback_snapshot(target, Path(snapshot_directory))
            try:
                copy_existing_to_backup(target, backup_root)
                protect_backup_from_discovery(backup_root)
                copy_harness_to_target(source, target)

                if not args.skip_validation:
                    run_validation(target, backup_root)
            except BaseException as error:
                rollback_failures = restore_rollback_snapshot(target, snapshot)
                if rollback_failures:
                    write_transaction_state(backup_root, "rollback-failed", error)
                    details = "; ".join(rollback_failures)
                    raise UpgradeError(
                        f"Harness upgrade failed: {error}. Backup: {backup_root}. "
                        f"Rollback failures: {details}"
                    ) from error
                write_transaction_state(backup_root, "rolled-back", error)
                raise UpgradeError(
                    f"Harness upgrade failed and was rolled back: {error}. Backup: {backup_root}"
                ) from error

        write_transaction_state(backup_root, "complete")

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

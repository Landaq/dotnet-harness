#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable


MODES = {"quick", "full", "core", "harness", "scaffold", "upgrade", "whitespace"}
GROUPS = {
    "quick": ("core", "harness", "upgrade", "whitespace"),
    "full": ("core", "harness", "scaffold", "upgrade", "whitespace"),
}

CATALOG_PAGES = (
    "index.html",
    "luna/index.html",
    "sol/index.html",
    "terra/index.html",
)


class ValidationError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def run(command: list[str], *, cwd: Path | None = None) -> None:
    completed = subprocess.run(command, cwd=cwd, check=False)
    if completed.returncode != 0:
        raise ValidationError(f"Command failed ({completed.returncode}): {' '.join(command)}")


def policy_match(content: str, expected: str) -> bool:
    tokens = re.findall(r"[\w@/$%+.-]+", expected, flags=re.UNICODE)
    if not tokens:
        return expected in content
    pattern = r"[\s\S]{0,120}".join(re.escape(token) for token in tokens)
    return re.search(pattern, content, flags=re.IGNORECASE) is not None


def seed_stale_catalog(root: Path, marker: str) -> None:
    catalog = root / ".codex/agent-categories"
    catalog.mkdir(parents=True, exist_ok=True)
    (catalog / "index.html").write_text(marker, encoding="utf-8")
    (catalog / "obsolete.html").write_text(marker, encoding="utf-8")


def require_catalog_matches(root: Path, source_root: Path) -> None:
    for relative in CATALOG_PAGES:
        installed = root / ".codex/agent-categories" / relative
        source = source_root / ".codex/agent-categories" / relative
        require(installed.is_file(), f"Installed harness missing catalog page: {relative}")
        require(source.is_file(), f"Harness source missing catalog page: {relative}")
        require(
            installed.read_bytes() == source.read_bytes(),
            f"Installed catalog page differs from source: {relative}",
        )
    require(
        not (root / ".codex/agent-categories/obsolete.html").exists(),
        "Catalog replacement retained a stale page.",
    )


def require_catalog_backup(root: Path, marker: str) -> None:
    backup_indexes = list(
        (root / ".codex/backups").glob(
            "harness-upgrade-*/agent-categories-backup/index.html"
        )
    )
    require(backup_indexes, "Harness upgrade did not back up the existing catalog.")
    require(
        any(path.read_text(encoding="utf-8") == marker for path in backup_indexes),
        "Catalog backup did not preserve the stale pre-upgrade catalog.",
    )
    require(
        any(
            (path.parent / "obsolete.html").read_text(encoding="utf-8") == marker
            for path in backup_indexes
            if (path.parent / "obsolete.html").is_file()
        ),
        "Catalog backup did not preserve the complete stale catalog tree.",
    )


class Context:
    def __init__(self, plugin_root: Path) -> None:
        self.plugin_root = plugin_root.resolve()
        self.skills_root = self.plugin_root / "skills"
        self.harness_root = self.plugin_root / "assets/harness"
        self.task_agents = self.skills_root / "task-agents/SKILL.md"
        self.manifest = self.plugin_root / ".codex-plugin/plugin.json"
        self.version = self.plugin_root / "VERSION.md"
        self.install = self.plugin_root / "install.py"
        self.install_windows = self.plugin_root / "install.ps1"
        self.install_macos = self.plugin_root / "install.zsh"
        self.upgrade = self.harness_root / ".codex/scripts/upgrade_harness.py"
        self.upgrade_windows = self.harness_root / ".codex/scripts/upgrade-harness.ps1"
        self.upgrade_macos = self.harness_root / ".codex/scripts/upgrade-harness.zsh"
        self.harness_validator = self.harness_root / ".codex/scripts/validate_task_agents.py"
        self.harness_validator_windows = self.harness_root / ".codex/scripts/validate-task-agents.ps1"
        self.harness_validator_macos = self.harness_root / ".codex/scripts/validate-task-agents.zsh"
        codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
        self.plugin_validator = codex_home / "skills/.system/plugin-creator/scripts/validate_plugin.py"
        self.skill_validator = codex_home / "skills/.system/skill-creator/scripts/quick_validate.py"


def host_wrapper_command(
    windows_script: Path,
    macos_script: Path,
    windows_args: tuple[str, ...],
    macos_args: tuple[str, ...],
) -> list[str]:
    if os.name == "nt":
        powershell = shutil.which("pwsh")
        require(powershell is not None, "pwsh is required for Windows wrapper validation.")
        return [powershell, "-NoProfile", "-File", str(windows_script), *windows_args]
    zsh = shutil.which("zsh")
    require(zsh is not None, "zsh is required for macOS wrapper validation.")
    return [zsh, str(macos_script), *macos_args]


def validate_core(ctx: Context) -> None:
    platform_files = (
        ctx.plugin_root / "install.ps1",
        ctx.plugin_root / "install.py",
        ctx.plugin_root / "install.zsh",
        ctx.plugin_root / "scripts/validate-release.ps1",
        ctx.plugin_root / "scripts/validate-release.zsh",
        ctx.plugin_root / "scripts/validation/requirements.txt",
        ctx.plugin_root / "scripts/validation/validate_release.py",
        ctx.harness_root / ".codex/scripts/python-env.zsh",
        ctx.harness_root / ".codex/scripts/python-env.ps1",
        ctx.harness_root / ".codex/scripts/upgrade-harness.ps1",
        ctx.harness_root / ".codex/scripts/upgrade-harness.zsh",
        ctx.harness_root / ".codex/scripts/upgrade_harness.py",
        ctx.harness_root / ".codex/scripts/validate-task-agents.ps1",
        ctx.harness_root / ".codex/scripts/validate-task-agents.zsh",
        ctx.harness_root / ".codex/scripts/validate_task_agents.py",
    )
    for path in platform_files:
        require(path.is_file(), f"Missing platform support file: {path}")

    bootstrap = ctx.skills_root / "project-structure-setup/scripts/bootstrap_project_structure.py"
    for path in (ctx.plugin_root.parent.parent / ".gitattributes", ctx.harness_root / ".gitattributes", bootstrap):
        content = path.read_text(encoding="utf-8")
        require("*.zsh text eol=lf" in content, f"Missing zsh LF policy: {path}")

    require(ctx.plugin_validator.is_file(), f"Missing plugin validator: {ctx.plugin_validator}")
    require(ctx.skill_validator.is_file(), f"Missing skill validator: {ctx.skill_validator}")
    run([sys.executable, str(ctx.plugin_validator), str(ctx.plugin_root)])
    for skill_dir in sorted(path for path in ctx.skills_root.iterdir() if path.is_dir()):
        if (skill_dir / "SKILL.md").is_file():
            run([sys.executable, str(ctx.skill_validator), str(skill_dir)])

    manifest = json.loads(ctx.manifest.read_text(encoding="utf-8"))
    version_text = ctx.version.read_text(encoding="utf-8")
    match = re.search(r"Current version:\s*`([^`]+)`", version_text)
    require(match is not None, "VERSION.md must contain a Current version line.")
    require(manifest["version"] == match.group(1), "plugin.json and VERSION.md versions differ.")
    require((ctx.plugin_root / "scripts/release-helper.ps1").is_file(), "Missing release helper.")

    require(not list(ctx.skills_root.rglob("SKILL.original.md")), "Remove legacy SKILL.original.md files.")
    require("TaskResult" not in ctx.manifest.read_text(encoding="utf-8"), "TaskResult must not be a default prompt.")
    references = ctx.skills_root / "task-agents/references"
    for name in (
        "workflow-modes.md",
        "phase-contracts.md",
        "delegation-policy.md",
        "worker-policy.md",
        "domain-policies.md",
        "task-result-and-git.md",
    ):
        require((references / name).is_file(), f"Missing Task Agents reference: {name}")
    require(not (ctx.harness_root / ".codex/skills").exists(), "Harness assets must not package repo-local skills.")

    package_manifest_path = ctx.skills_root / "project-structure-setup/references/package-versions.json"
    package_manifest = json.loads(package_manifest_path.read_text(encoding="utf-8"))
    packages = package_manifest.get("packages", {})
    for name in (
        "Aspire.Hosting.AppHost",
        "Aspire.Hosting.SqlServer",
        "Aspire.Hosting.Redis",
        "Microsoft.AspNetCore.Components.WebAssembly",
        "Microsoft.AspNetCore.Components.WebAssembly.Server",
        "Microsoft.EntityFrameworkCore.SqlServer",
        "Microsoft.AspNetCore.OpenApi",
        "Microsoft.Extensions.DependencyInjection.Abstractions",
        "MudBlazor",
        "Scalar.AspNetCore",
        "Yarp.ReverseProxy",
        "Microsoft.NET.Test.Sdk",
        "xunit",
    ):
        require(name in packages, f"package-versions.json missing required package: {name}")

    bootstrap = bootstrap.read_text(encoding="utf-8")
    for expected in ("package-versions.json", "_package_versions_props", "json.load"):
        require(policy_match(bootstrap, expected), f"Bootstrap missing package contract: {expected}")
    print(f"Core validation passed: {ctx.plugin_root}")


def validate_harness(ctx: Context) -> None:
    require(ctx.harness_validator.is_file(), f"Missing harness validator: {ctx.harness_validator}")
    run(
        host_wrapper_command(
            ctx.harness_validator_windows,
            ctx.harness_validator_macos,
            ("-RepoRoot", str(ctx.harness_root)),
            ("--repo-root", str(ctx.harness_root)),
        )
    )

    references = ctx.skills_root / "task-agents/references"
    policy = ctx.task_agents.read_text(encoding="utf-8")
    for path in sorted(references.glob("*.md")):
        policy += "\n" + path.read_text(encoding="utf-8")
    required_policy = (
        "Workflow Modes",
        "Clarify Before Delegating",
        "Delegation Evidence",
        "Structured Agent Handoff",
        "Mandatory Socratic Checkpoint",
        "Subagent Utilization Floor",
        "Task Agents must clarify before delegating.",
        "Delegation: used",
        "Delegation: skipped no-explicit-agent-request",
        "TaskResult remains opt-in only.",
        "Requirement Intake",
        "Socratic Clarification",
        "Ambiguity Recalculation",
        "Goal Boundary Confirmation",
        "Subagent Handoff",
        "Worker Implementation",
        "Review Agent",
        "Verification Agent",
        "Main Thread Final Summary",
        "Worker agents are `standard`/`deep` only",
        "target average ambiguity `<= 8%`",
        "Findings:",
        "Changes:",
        "Risks:",
        "Verify:",
        "Next:",
    )
    for expected in required_policy:
        require(policy_match(policy, expected), f"Task Agents policy missing: {expected}")

    agents_root = ctx.harness_root / ".codex/agents"
    structured_agents = (
        "03-service-template.toml",
        "04-frontend-ui.toml",
        "05-tdd-test.toml",
        "06-reference-auditor.toml",
        "08-implementation-coordinator.toml",
        "09-code-reviewer.toml",
        "10-verification-runner.toml",
        "12-backend-worker.toml",
        "13-frontend-worker.toml",
        "14-test-worker.toml",
        "15-docs-harness-worker.toml",
        "16-backend-reviewer.toml",
        "17-frontend-reviewer.toml",
        "18-test-reviewer.toml",
        "19-docs-harness-reviewer.toml",
        "20-feature-slicer.toml",
        "21-docs-harness-specialist.toml",
    )
    for name in structured_agents:
        content = (agents_root / name).read_text(encoding="utf-8")
        for expected in ("Findings", "Changes", "Risks", "Verify", "Next", "Preserve exact file paths, commands, errors, API names"):
            require(policy_match(content, expected), f"{name} missing structured handoff contract: {expected}")

    coordinator = (agents_root / "08-implementation-coordinator.toml").read_text(encoding="utf-8")
    for expected in (
        "Require actual subagent tool calls such as `spawn_agent`",
        "A delegation plan is not delegation evidence.",
        "Route non-trivial multi-area work through `feature-slicer`",
        "Use feature-scoped read-only specialists",
        "Route post-implementation checks to the smallest relevant reviewer set",
        "Split review work by feature slice.",
    ):
        require(policy_match(coordinator, expected), f"Implementation coordinator missing: {expected}")

    config = ctx.harness_root / ".codex/harness-config.json"
    require(config.is_file(), f"Missing harness config: {config}")
    config_text = config.read_text(encoding="utf-8")
    for expected in ("defaultLibrary", "biLibrary", "devExpressVersion"):
        require(expected in config_text, f"Harness config missing: {expected}")
    print(f"Harness validation passed: {ctx.plugin_root}")


def validate_upgrade(ctx: Context) -> None:
    require(ctx.install.is_file(), f"Missing install core: {ctx.install}")
    require(ctx.upgrade.is_file(), f"Missing upgrade core: {ctx.upgrade}")

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-harnessonly-") as temp:
        root = Path(temp)
        run(
            host_wrapper_command(
                ctx.install_windows,
                ctx.install_macos,
                ("-Root", str(root), "-ProjectName", "HarnessOnlySmoke", "-HarnessOnly"),
                ("--root", str(root), "--project-name", "HarnessOnlySmoke", "--harness-only"),
            )
        )
        require(not (root / "src").exists() and not (root / "test").exists(), "Harness-only install created app folders.")
        for relative in (
            "AGENTS.md",
            ".codex/agent-categories",
            ".codex/agents",
            ".codex/scripts",
        ):
            require((root / relative).exists(), f"Harness-only install missing {relative}")
        require_catalog_matches(root, ctx.harness_root)

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-install-upgrade-") as temp:
        root = Path(temp)
        (root / ".codex/agents").mkdir(parents=True)
        (root / "AGENTS.md").write_text("# Legacy\n", encoding="utf-8")
        (root / ".codex/agents/legacy.toml").write_text(
            'name = "legacy"\n[policy]\nworkflow_modes = ["legacy"]\n',
            encoding="utf-8",
        )
        catalog_marker = "stale install-driven catalog"
        seed_stale_catalog(root, catalog_marker)
        run(
            host_wrapper_command(
                ctx.install_windows,
                ctx.install_macos,
                ("-Root", str(root), "-ProjectName", "InstallUpgradeSmoke", "-HarnessOnly"),
                ("--root", str(root), "--project-name", "InstallUpgradeSmoke", "--harness-only"),
            )
        )
        require((root / ".codex/backups").is_dir(), "Install-driven upgrade did not create a backup.")
        require_catalog_matches(root, ctx.harness_root)
        require_catalog_backup(root, catalog_marker)
        for agent in (root / ".codex/agents").glob("*.toml"):
            require("[policy]" not in agent.read_text(encoding="utf-8"), "Install-driven upgrade left a legacy policy table.")

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-upgrade-") as temp:
        root = Path(temp)
        (root / ".codex/agents").mkdir(parents=True)
        (root / ".codex/skills/legacy").mkdir(parents=True)
        (root / ".codex/agents/legacy.toml").write_text('name = "legacy"\n', encoding="utf-8")
        (root / ".codex/skills/legacy/SKILL.md").write_text("# Legacy\n", encoding="utf-8")
        catalog_marker = "stale direct-upgrade catalog"
        seed_stale_catalog(root, catalog_marker)
        run(
            host_wrapper_command(
                ctx.upgrade_windows,
                ctx.upgrade_macos,
                ("-TargetRoot", str(root), "-SourceRoot", str(ctx.harness_root)),
                ("--target-root", str(root), "--source-root", str(ctx.harness_root)),
            )
        )
        run(
            host_wrapper_command(
                ctx.upgrade_windows,
                ctx.upgrade_macos,
                ("-TargetRoot", str(root), "-SourceRoot", str(ctx.harness_root), "-Apply"),
                ("--target-root", str(root), "--source-root", str(ctx.harness_root), "--apply"),
            )
        )
        require(not (root / ".codex/skills").exists(), "Upgrade left active repo-local skills.")
        for relative in (
            ".gitignore",
            ".gitattributes",
            ".codex/harness-config.json",
            ".codex/agent-categories",
            ".codex/agents",
            ".codex/scripts",
        ):
            require((root / relative).exists(), f"Upgrade missing {relative}")
        require_catalog_matches(root, ctx.harness_root)
        require_catalog_backup(root, catalog_marker)
        require(list((root / ".codex/backups").rglob("*.bak")), "Upgrade did not protect backup discovery files.")
    print(f"Upgrade validation passed: {ctx.plugin_root}")


def validate_scaffold(ctx: Context) -> None:
    require(shutil.which("dotnet") is not None, "dotnet is required for scaffold validation.")
    for project_name, service_name in (("SmokeNoService", None), ("SmokeWithService", "Auth")):
        with tempfile.TemporaryDirectory(prefix="dotnet-harness-smoke-") as temp:
            root = Path(temp)
            windows_args = ["-Root", str(root), "-ProjectName", project_name]
            macos_args = ["--root", str(root), "--project-name", project_name]
            if service_name:
                windows_args.extend(("-ServiceName", service_name))
                macos_args.extend(("--service-name", service_name))
            else:
                windows_args.append("-NoService")
                macos_args.append("--no-service")
            command = host_wrapper_command(
                ctx.install_windows,
                ctx.install_macos,
                tuple(windows_args),
                tuple(macos_args),
            )
            run(command)
            solution = root / f"{project_name}.slnx"
            require(solution.is_file(), f"Scaffold missing solution: {solution}")
            run(["dotnet", "restore", solution.name], cwd=root)
            run(["dotnet", "build", solution.name, "--no-restore"], cwd=root)
            run(["dotnet", "test", solution.name, "--no-build"], cwd=root)
    print(f"Scaffold validation passed: {ctx.plugin_root}")


def validate_whitespace(ctx: Context) -> None:
    completed = subprocess.run(
        ["git", "-C", str(ctx.plugin_root), "rev-parse", "--show-toplevel"],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        print("Skipping git diff --check: plugin root is not in a git repository.")
        return
    git_root = Path(completed.stdout.strip())
    relative = ctx.plugin_root.relative_to(git_root)
    run(["git", "-C", str(git_root), "diff", "--check", "--", str(relative)])
    print(f"Whitespace validation passed: {ctx.plugin_root}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate the dotnet-harness plugin")
    parser.add_argument("--plugin-root", default=Path(__file__).resolve().parents[2])
    parser.add_argument("--mode", default="Quick")
    parser.add_argument("--include-scaffold", action="store_true")
    args = parser.parse_args()
    args.mode = args.mode.lower()
    if args.mode not in MODES:
        parser.error(f"--mode must be one of: {', '.join(sorted(MODES))}")
    return args


def main() -> int:
    if sys.version_info < (3, 11):
        raise SystemExit("Release validation requires Python 3.11 or newer.")
    args = parse_args()
    ctx = Context(Path(args.plugin_root))
    validators: dict[str, Callable[[Context], None]] = {
        "core": validate_core,
        "harness": validate_harness,
        "scaffold": validate_scaffold,
        "upgrade": validate_upgrade,
        "whitespace": validate_whitespace,
    }
    groups = list(GROUPS.get(args.mode, (args.mode,)))
    if args.include_scaffold and "scaffold" not in groups:
        groups.insert(max(0, len(groups) - 1), "scaffold")

    failures: list[str] = []
    for group in groups:
        print(f"[group] {group}")
        try:
            validators[group](ctx)
        except (OSError, ValueError, ValidationError) as exc:
            failures.append(f"{group}: {exc}")
    if failures:
        print("Release validation failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"Release validation passed ({args.mode.title()}): {ctx.plugin_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

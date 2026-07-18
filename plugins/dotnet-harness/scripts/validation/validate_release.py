#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
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


def run(
    command: list[str],
    *,
    cwd: Path | None = None,
    timeout: int | None = None,
) -> None:
    try:
        completed = subprocess.run(command, cwd=cwd, check=False, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        raise ValidationError(
            f"Command timed out after {timeout}s: {' '.join(command)}"
        ) from exc
    if completed.returncode != 0:
        raise ValidationError(f"Command failed ({completed.returncode}): {' '.join(command)}")


def policy_match(content: str, expected: str) -> bool:
    tokens = re.findall(r"[\w@/$%+.-]+", expected, flags=re.UNICODE)
    if not tokens:
        return expected in content
    pattern = r"[\s\S]{0,120}".join(re.escape(token) for token in tokens)
    return re.search(pattern, content, flags=re.IGNORECASE) is not None


def require_text(path: Path, *expected: str) -> str:
    require(path.is_file(), f"Missing scaffold file: {path}")
    content = path.read_text(encoding="utf-8")
    for value in expected:
        require(value in content, f"{path} missing scaffold contract: {value}")
    return content


def require_scaffold_contract(root: Path, project_name: str, service_name: str | None) -> None:
    global_json = json.loads((root / "global.json").read_text(encoding="utf-8"))
    require(global_json["sdk"]["version"].startswith("10."), "Scaffold must pin .NET 10 SDK.")
    require_text(root / "Directory.Build.props", "<TargetFramework>net10.0</TargetFramework>")
    ET.parse(root / "Directory.Packages.props")

    require_text(
        root / "src/Aspire/AppHost/Program.cs",
        'AddSqlServer("sql")',
        'AddRedis("redis")',
        "WithReference(sql)",
        "WithReference(redis)",
    )
    require_text(
        root / "src/BackEnd/APIGateway/Program.cs",
        "AddReverseProxy",
        "MapScalarApiReference",
        "MapReverseProxy",
    )
    require_text(
        root / "test/Functional/APIGateway/APIGatewayBaselineTests.cs",
        "WebApplicationFactory<global::Program>",
        'GetAsync("/api/health")',
        "HttpStatusCode.OK",
    )
    proxy = json.loads(
        (root / "src/BackEnd/APIGateway/appsettings.json").read_text(encoding="utf-8")
    )["ReverseProxy"]
    require(isinstance(proxy.get("Routes"), dict), "Gateway must define YARP Routes.")
    require(isinstance(proxy.get("Clusters"), dict), "Gateway must define YARP Clusters.")

    require_text(
        root / "src/BackEnd/BuildingBlocks/Application/Mediator/IRequestDispatcher.cs",
        "interface IRequestDispatcher",
        "Task<TResponse> Send<TResponse>",
    )
    require_text(
        root / "src/BackEnd/BuildingBlocks/Application/Mediator/RequestDispatcher.cs",
        "sealed class RequestDispatcher",
        "GetRequiredService",
    )
    require_text(
        root / "src/FrontEnd/Web/Program.cs",
        "AddInteractiveWebAssemblyComponents",
        "AddInteractiveWebAssemblyRenderMode",
    )
    require_text(
        root / "src/FrontEnd/Web.Client/Routes.razor",
        'AppAssembly="typeof(Program).Assembly"',
        "MainLayout",
    )
    require_text(
        root / "src/FrontEnd/Web/App.razor",
        "MudBlazor.min.css",
        "MudBlazor.min.js",
        '<Web.Client.Routes @rendermode="InteractiveAuto" />',
        '<HeadOutlet @rendermode="InteractiveAuto" />',
    )
    require_text(
        root / "src/FrontEnd/Web.Client/Layout/MudProviders.razor",
        "MudThemeProvider",
        "MudPopoverProvider",
        "MudDialogProvider",
        "MudSnackbarProvider",
    )
    require(
        not (root / "src/FrontEnd/Web/Routes.razor").exists()
        and not (root / "src/FrontEnd/Web/Components/Layout/MainLayout.razor").exists(),
        "Interactive router and layout must be owned by the Web.Client project.",
    )

    apphost = (root / "src/Aspire/AppHost/Program.cs").read_text(encoding="utf-8")
    resource_names = re.findall(
        r'(?:AddDatabase|AddProject<[^>]+>)\("([^"]+)"\)',
        apphost,
    )
    require(resource_names, "AppHost must declare named Aspire resources.")
    for resource_name in resource_names:
        require(
            len(resource_name) <= 64
            and re.fullmatch(r"[A-Za-z](?:[A-Za-z0-9]|-(?!-))*", resource_name) is not None,
            f"Invalid Aspire resource name: {resource_name}",
        )

    solution = ET.parse(root / f"{project_name}.slnx").getroot()
    solution_projects = {
        element.attrib["Path"].replace("\\", "/")
        for element in solution.iter("Project")
    }
    expected_projects = {
        "src/Aspire/AppHost/AppHost.csproj",
        "src/BackEnd/APIGateway/APIGateway.csproj",
        "src/FrontEnd/Web/Web.csproj",
        "src/FrontEnd/Web.Client/Web.Client.csproj",
        "test/Architecture/Architecture.Tests.csproj",
        "test/Unit/Unit.Tests.csproj",
        "test/Functional/APIGateway/APIGateway.FunctionalTests.csproj",
    }
    require(expected_projects <= solution_projects, "Solution is missing baseline projects.")

    services_root = root / "src/BackEnd/Services"
    if service_name is None:
        require(
            not services_root.exists() or not any(services_root.iterdir()),
            "No-service scaffold created a service project.",
        )
        return

    require(proxy["Routes"], "Service scaffold must define a YARP route.")
    require(proxy["Clusters"], "Service scaffold must define a YARP cluster.")
    service_projects = {
        f"src/BackEnd/Services/{service_name}/{service_name}.{layer}/{service_name}.{layer}.csproj"
        for layer in ("Domain", "Application", "Infrastructure", "Api", "Contracts")
    }
    service_projects.update(
        {
            f"test/Unit/Services/{service_name}/{service_name}.UnitTests.csproj",
            f"test/Integration/Services/{service_name}/{service_name}.IntegrationTests.csproj",
            f"test/Contract/Services/{service_name}/{service_name}.ContractTests.csproj",
        }
    )
    require(service_projects <= solution_projects, "Solution is missing service projects.")
    for relative in service_projects:
        require((root / relative).is_file(), f"Missing service project: {relative}")
    require_text(
        root / "src/Aspire/AppHost/Program.cs",
        f"Projects.{service_name}_Api",
        f'AddProject<Projects.{service_name}_Api>',
    )
    proxy_text = json.dumps(proxy)
    require(service_name.lower() in proxy_text.lower(), "Gateway is missing the service route.")


def tree_snapshot(root: Path) -> dict[str, bytes | None]:
    return {
        str(path.relative_to(root)): path.read_bytes() if path.is_file() else None
        for path in sorted(root.rglob("*"))
    }


def require_command_failure(command: list[str], *, timeout: int = 60) -> str:
    try:
        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        raise ValidationError(f"Expected failure timed out: {' '.join(command)}") from exc
    require(completed.returncode != 0, f"Command unexpectedly succeeded: {' '.join(command)}")
    return completed.stdout + completed.stderr


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
        self.bootstrap = self.skills_root / "project-structure-setup/scripts/bootstrap_project_structure.py"
        self.upgrade = self.harness_root / ".codex/scripts/upgrade_harness.py"
        self.upgrade_windows = self.harness_root / ".codex/scripts/upgrade-harness.ps1"
        self.upgrade_macos = self.harness_root / ".codex/scripts/upgrade-harness.zsh"
        self.harness_validator = self.harness_root / ".codex/scripts/validate_task_agents.py"
        self.harness_validator_windows = self.harness_root / ".codex/scripts/validate-task-agents.ps1"
        self.harness_validator_macos = self.harness_root / ".codex/scripts/validate-task-agents.zsh"
        codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
        self.plugin_validator = codex_home / "skills/.system/plugin-creator/scripts/validate_plugin.py"
        self.skill_validator = codex_home / "skills/.system/skill-creator/scripts/quick_validate.py"
        self.browser_e2e = False


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


def validation_command_for_test(root: Path) -> tuple[Path, list[str]]:
    scripts = root / ".codex/scripts"
    if os.name == "nt":
        validator = scripts / "validate-task-agents.ps1"
        return validator, ["pwsh", "-NoProfile", "-File", str(validator), "-RepoRoot", str(root)]
    validator = scripts / "validate-task-agents.zsh"
    return validator, ["zsh", str(validator), "--repo-root", str(root)]


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

    bootstrap = ctx.bootstrap
    for path in (ctx.plugin_root.parent.parent / ".gitattributes", ctx.harness_root / ".gitattributes", bootstrap):
        content = path.read_text(encoding="utf-8")
        require("*.zsh text eol=lf" in content, f"Missing zsh LF policy: {path}")

    skip_system_validators = os.environ.get("DOTNET_HARNESS_SKIP_SYSTEM_VALIDATORS") == "1"
    if skip_system_validators:
        require(
            os.environ.get("GITHUB_ACTIONS") == "true",
            "System validator bypass is restricted to GitHub Actions.",
        )
        print("Skipping Codex system validators in GitHub Actions; local Full remains authoritative.")
    else:
        require(ctx.plugin_validator.is_file(), f"Missing plugin validator: {ctx.plugin_validator}")
        require(ctx.skill_validator.is_file(), f"Missing skill validator: {ctx.skill_validator}")
        run([sys.executable, str(ctx.plugin_validator), str(ctx.plugin_root)])
        for skill_dir in sorted(path for path in ctx.skills_root.iterdir() if path.is_dir()):
            if (skill_dir / "SKILL.md").is_file():
                run([sys.executable, str(ctx.skill_validator), str(skill_dir)])

    manifest = json.loads(ctx.manifest.read_text(encoding="utf-8"))
    mcp_config = json.loads((ctx.plugin_root / ".mcp.json").read_text(encoding="utf-8"))
    context7_args = mcp_config["mcpServers"]["context7"]["args"]
    require(
        "@upstash/context7-mcp@3.0.0" in context7_args,
        "Context7 MCP must be pinned to the reviewed release.",
    )
    version_text = ctx.version.read_text(encoding="utf-8")
    match = re.search(r"Current version:\s*`([^`]+)`", version_text)
    require(match is not None, "VERSION.md must contain a Current version line.")
    require(manifest["version"] == match.group(1), "plugin.json and VERSION.md versions differ.")
    require((ctx.plugin_root / "scripts/release-helper.ps1").is_file(), "Missing release helper.")
    require((ctx.plugin_root / "MIGRATION.md").is_file(), "Missing release migration guide.")
    workflow = ctx.plugin_root.parent.parent / ".github/workflows/validate.yml"
    require_text(
        workflow,
        "windows-latest",
        "macos-latest",
        "playwright install chromium",
        "DOTNET_HARNESS_SKIP_SYSTEM_VALIDATORS",
        "-Mode Full",
        "--mode Full",
    )

    for group in ("core", "harness", "scaffold", "upgrade", "whitespace"):
        wrapper = ctx.plugin_root / f"scripts/validation/validate-{group}.ps1"
        wrapper_text = require_text(wrapper, "validate-release.ps1", "exit $LASTEXITCODE")
        require(
            f"-Mode {group.title()}" in wrapper_text,
            f"Compatibility wrapper does not forward the {group.title()} mode: {wrapper}",
        )

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
    sdks = package_manifest.get("sdks", {})
    require("Aspire.AppHost.Sdk" in sdks, "package-versions.json missing Aspire AppHost SDK.")
    packages = package_manifest.get("packages", {})
    for name in (
        "Aspire.Hosting.AppHost",
        "Aspire.Hosting.SqlServer",
        "Aspire.Hosting.Redis",
        "Microsoft.AspNetCore.Components.WebAssembly",
        "Microsoft.AspNetCore.Components.WebAssembly.Server",
        "Microsoft.AspNetCore.Mvc.Testing",
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
            "docs/Project",
            "global.json",
            "Directory.Build.props",
            "Directory.Packages.props",
            "HarnessOnlySmoke.slnx",
        ):
            require(not (root / relative).exists(), f"Harness-only install created scaffold artifact: {relative}")
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

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-upgrade-unique-") as temp:
        root = Path(temp)
        historical_agent = root / ".codex/backups/historical/agents-backup/legacy.toml"
        historical_agent.parent.mkdir(parents=True)
        historical_agent.write_text('name = "legacy"\n', encoding="utf-8")
        command = [
            sys.executable,
            str(ctx.upgrade),
            "--target-root",
            str(root),
            "--source-root",
            str(ctx.harness_root),
            "--apply",
            "--skip-validation",
        ]
        run(command, timeout=60)
        run(command, timeout=60)
        backups = list((root / ".codex/backups").glob("harness-upgrade-*"))
        require(len(backups) == 2, "Immediate upgrades did not allocate isolated backups.")
        for backup in backups:
            state = json.loads((backup / "transaction-state.json").read_text(encoding="utf-8"))
            require(state["state"] == "complete", f"Upgrade backup is not complete: {backup}")
        require(historical_agent.is_file(), "Upgrade mutated a historical backup agent.")
        require(
            not historical_agent.with_suffix(".toml.bak").exists(),
            "Upgrade re-protected a historical backup.",
        )

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-upgrade-rollback-") as temp:
        root = Path(temp)
        source = root / "source"
        target = root / "target"
        shutil.copytree(ctx.harness_root, source)
        target.mkdir()
        (target / ".codex/agents").mkdir(parents=True)
        (target / "AGENTS.md").write_text("# Original\n", encoding="utf-8")
        (target / ".gitignore").write_text("original-ignore\n", encoding="utf-8")
        (target / ".codex/agents/original.toml").write_text(
            'name = "original"\n', encoding="utf-8"
        )
        validator, _ = validation_command_for_test(source)
        validator.write_text("#!/bin/zsh\nexit 23\n", encoding="utf-8")
        output = require_command_failure(
            [
                sys.executable,
                str(ctx.upgrade),
                "--target-root",
                str(target),
                "--source-root",
                str(source),
                "--apply",
            ]
        )
        require("rolled back" in output.lower(), "Upgrade failure did not report rollback.")
        require_text(target / "AGENTS.md", "# Original")
        require_text(target / ".gitignore", "original-ignore")
        require((target / ".codex/agents/original.toml").is_file(), "Rollback lost original agent.")
        for relative in (".gitattributes", ".codex/harness-config.json", ".codex/agent-categories", ".codex/scripts"):
            require(not (target / relative).exists(), f"Rollback retained newly managed path: {relative}")
        require(
            list((target / ".codex/backups").glob("harness-upgrade-*")),
            "Rollback did not preserve the diagnostic backup.",
        )
        rollback_backup = next((target / ".codex/backups").glob("harness-upgrade-*"))
        rollback_state = json.loads(
            (rollback_backup / "transaction-state.json").read_text(encoding="utf-8")
        )
        require(rollback_state["state"] == "rolled-back", "Rollback state was not recorded.")

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-upgrade-no-validator-") as temp:
        root = Path(temp)
        source = root / "source"
        target = root / "target"
        shutil.copytree(ctx.harness_root, source)
        validator, _ = validation_command_for_test(source)
        validator.unlink()
        target.mkdir()
        (target / "sentinel.txt").write_text("unchanged", encoding="utf-8")
        before = tree_snapshot(target)
        require_command_failure(
            [
                sys.executable,
                str(ctx.upgrade),
                "--target-root",
                str(target),
                "--source-root",
                str(source),
                "--apply",
            ]
        )
        require(tree_snapshot(target) == before, "Missing source validator mutated the target.")

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-upgrade-symlink-parent-") as temp:
        root = Path(temp)
        target = root / "target"
        external = root / "external"
        target.mkdir()
        (external / "agents").mkdir(parents=True)
        sentinel = external / "agents/sentinel.txt"
        sentinel.write_text("outside", encoding="utf-8")
        (target / ".codex").symlink_to(external, target_is_directory=True)
        require_command_failure(
            [
                sys.executable,
                str(ctx.upgrade),
                "--target-root",
                str(target),
                "--source-root",
                str(ctx.harness_root),
                "--apply",
                "--skip-validation",
            ]
        )
        require_text(sentinel, "outside")
        require(not (external / "backups").exists(), "Symlink preflight wrote an external backup.")

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-upgrade-lock-") as temp:
        target = Path(temp)
        lock = target / ".codex/.harness-upgrade.lock"
        lock.parent.mkdir()
        lock.write_text("pid=test\n", encoding="utf-8")
        before = tree_snapshot(target)
        require_command_failure(
            [
                sys.executable,
                str(ctx.upgrade),
                "--target-root",
                str(target),
                "--source-root",
                str(ctx.harness_root),
                "--apply",
                "--skip-validation",
            ]
        )
        require(tree_snapshot(target) == before, "Concurrent-upgrade lock failure mutated target.")

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-upgrade-symlink-file-") as temp:
        root = Path(temp)
        target = root / "target"
        target.mkdir()
        external_agents = root / "external-AGENTS.md"
        external_agents.write_text("outside", encoding="utf-8")
        installed_agents = target / "AGENTS.md"
        installed_agents.symlink_to(external_agents)
        run(
            [
                sys.executable,
                str(ctx.upgrade),
                "--target-root",
                str(target),
                "--source-root",
                str(ctx.harness_root),
                "--apply",
                "--skip-validation",
            ],
            timeout=60,
        )
        require_text(external_agents, "outside")
        require(not installed_agents.is_symlink(), "Upgrade retained the managed AGENTS.md symlink.")
        require(
            installed_agents.read_bytes() == (ctx.harness_root / "AGENTS.md").read_bytes(),
            "Upgrade did not install the source AGENTS.md after replacing a symlink.",
        )
    print(f"Upgrade validation passed: {ctx.plugin_root}")


def _available_tcp_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.bind(("127.0.0.1", 0))
        return int(server.getsockname()[1])


def _read_log_tail(log: object, limit: int = 20_000) -> str:
    log.seek(0)
    content = log.read()
    return content if len(content) <= limit else f"[earlier log omitted]\n{content[-limit:]}"


def _wait_for_http(url: str, process: subprocess.Popen[str], log: object) -> None:
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise ValidationError(
                f"Blazor test server exited early:\n{_read_log_tail(log)}"
            )
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                if response.status < 500:
                    return
        except (urllib.error.URLError, TimeoutError):
            time.sleep(0.5)
    raise ValidationError(
        f"Blazor test server did not become ready: {url}\n{_read_log_tail(log)}"
    )


def validate_blazor_wasm_handoff(root: Path) -> None:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise ValidationError(
            "Playwright is required for Full validation; install validation requirements first."
        ) from exc

    publish_root = root / ".artifacts/browser-e2e"
    run(
        [
            "dotnet",
            "publish",
            "src/FrontEnd/Web/Web.csproj",
            "--configuration",
            "Release",
            "--no-restore",
            "--output",
            str(publish_root),
        ],
        cwd=root,
        timeout=600,
    )

    port = _available_tcp_port()
    url = f"http://127.0.0.1:{port}/interactive"
    environment = os.environ.copy()
    environment.update(
        {
            "ASPNETCORE_ENVIRONMENT": "Production",
            "ASPNETCORE_URLS": f"http://127.0.0.1:{port}",
            "DOTNET_NOLOGO": "1",
        }
    )
    log = tempfile.TemporaryFile(mode="w+", encoding="utf-8")
    process = subprocess.Popen(
        ["dotnet", str(publish_root / "Web.dll")],
        cwd=publish_root,
        env=environment,
        stdout=log,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        _wait_for_http(url, process, log)
        with sync_playwright() as playwright:
            launch_options: dict[str, object] = {"headless": True}
            browser_channel = os.environ.get("DOTNET_HARNESS_BROWSER_CHANNEL")
            if browser_channel:
                launch_options["channel"] = browser_channel
            try:
                browser = playwright.chromium.launch(**launch_options)
            except Exception as exc:
                raise ValidationError(
                    "Chromium is unavailable; run 'python -m playwright install chromium'."
                ) from exc

            try:
                context = browser.new_context()
                pending_framework_requests: set[str] = set()
                completed_framework_resources: list[str] = []
                last_framework_activity = [time.monotonic()]
                first_page = context.new_page()

                def framework_request_started(request: object) -> None:
                    if "/_framework/" in request.url:
                        pending_framework_requests.add(request.url)
                        last_framework_activity[0] = time.monotonic()

                def framework_request_finished(request: object) -> None:
                    if "/_framework/" in request.url:
                        pending_framework_requests.discard(request.url)
                        completed_framework_resources.append(request.url)
                        last_framework_activity[0] = time.monotonic()

                first_page.on("request", framework_request_started)
                first_page.on("requestfinished", framework_request_finished)
                first_page.on("requestfailed", framework_request_finished)
                first_page.goto(url, wait_until="domcontentloaded", timeout=60_000)
                first_button = first_page.get_by_role("button", name="Increment", exact=True)
                first_button.wait_for(timeout=60_000)

                download_deadline = time.monotonic() + 120
                while True:
                    app_bundle_downloaded = any(
                        "/_framework/Web.Client." in resource
                        and resource.endswith(".wasm")
                        for resource in completed_framework_resources
                    )
                    framework_idle = (
                        not pending_framework_requests
                        and time.monotonic() - last_framework_activity[0] >= 1.5
                    )
                    if app_bundle_downloaded and framework_idle:
                        break
                    if time.monotonic() >= download_deadline:
                        raise ValidationError(
                            "InteractiveAuto did not finish downloading the WebAssembly app bundle."
                        )
                    first_page.wait_for_timeout(500)
                first_page.close()

                blocked_blazor_requests: list[str] = []

                def block_server_interactivity(route: object) -> None:
                    request_url = route.request.url
                    request_path = urllib.parse.urlsplit(request_url).path.rstrip("/")
                    if request_path in {"/_blazor", "/_blazor/negotiate"}:
                        blocked_blazor_requests.append(request_url)
                        route.abort()
                    else:
                        route.continue_()

                context.route("**/*", block_server_interactivity)
                second_page = context.new_page()
                page_errors: list[str] = []
                second_page.on("pageerror", lambda error: page_errors.append(str(error)))
                second_page.goto(url, wait_until="domcontentloaded", timeout=60_000)
                second_button = second_page.get_by_role("button", name="Increment", exact=True)
                second_button.wait_for(timeout=60_000)
                positive_count = second_page.get_by_text(
                    re.compile(r"Count: [1-9]\d*"),
                    exact=True,
                )
                interaction_deadline = time.monotonic() + 120
                while not positive_count.is_visible():
                    second_button.click()
                    if time.monotonic() >= interaction_deadline:
                        raise ValidationError(
                            "The WebAssembly counter did not become interactive after reload."
                        )
                    second_page.wait_for_timeout(500)
                require(
                    not blocked_blazor_requests,
                    "Second InteractiveAuto load attempted server interactivity instead of WebAssembly.",
                )
                require(not page_errors, f"Browser page errors during WebAssembly handoff: {page_errors}")
                context.close()
            finally:
                browser.close()
    except ValidationError:
        raise
    except Exception as exc:
        raise ValidationError(
            f"Blazor browser validation failed: {exc}\n{_read_log_tail(log)}"
        ) from exc
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)
        log.close()

    print("Blazor InteractiveAuto WebAssembly handoff validation passed.")


def validate_scaffold(ctx: Context) -> None:
    require(shutil.which("dotnet") is not None, "dotnet is required for scaffold validation.")
    with tempfile.TemporaryDirectory(prefix="dotnet-harness-invalid-name-") as temp:
        parent = Path(temp)
        escape_name = f"{parent.name}-escape"
        escaped_solution = parent.parent / f"{escape_name}.slnx"
        for index, arguments in enumerate(
            (
                ("--project-name", f"../../{escape_name}", "--no-service"),
                ("--project-name", "SafeProject", "--service-name", "Order-Service"),
                ("--project-name", 'Bad"Name', "--no-service"),
            )
        ):
            root = parent / f"case-{index}"
            root.mkdir()
            require_command_failure(
                [sys.executable, str(ctx.bootstrap), "--root", str(root), *arguments]
            )
            require(not tree_snapshot(root), f"Invalid scaffold name wrote partial files: {arguments}")
        if escaped_solution.exists():
            escaped_solution.unlink()
            raise ValidationError("Project name escaped the target root.")

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-install-preflight-") as temp:
        root = Path(temp)
        (root / "AGENTS.md").write_text("existing harness", encoding="utf-8")
        for arguments in (
            ("--project-name", "../../escape", "--no-service"),
            ("--project-name", "P" * 121, "--no-service"),
            ("--project-name", "SafeProject", "--service-name", "S" * 65),
        ):
            before = tree_snapshot(root)
            require_command_failure(
                [sys.executable, str(ctx.install), "--root", str(root), *arguments]
            )
            require(
                tree_snapshot(root) == before,
                f"Install preflight mutated the harness before rejecting input: {arguments}",
            )

    with tempfile.TemporaryDirectory(prefix="dotnet-harness-service-rerun-") as temp:
        root = Path(temp)
        run(
            [
                sys.executable,
                str(ctx.bootstrap),
                "--root",
                str(root),
                "--project-name",
                "RerunSmoke",
                "--no-service",
            ],
            timeout=60,
        )
        before = tree_snapshot(root)
        require_command_failure(
            [
                sys.executable,
                str(ctx.bootstrap),
                "--root",
                str(root),
                "--project-name",
                "RerunSmoke",
                "--service-name",
                "Auth",
            ]
        )
        require(tree_snapshot(root) == before, "Service rerun changed the existing scaffold.")

    long_project_name = "123" + ("Long" * 17) + "--Name"
    long_service_name = "S" * 61
    for project_name, service_name in (
        (long_project_name, None),
        ("SmokeWithService", long_service_name),
    ):
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
            require_scaffold_contract(root, project_name, service_name)
            run(["dotnet", "restore", solution.name], cwd=root, timeout=600)
            run(["dotnet", "build", solution.name, "--no-restore"], cwd=root, timeout=600)
            run(
                ["dotnet", "test", solution.name, "--no-build", "--no-restore"],
                cwd=root,
                timeout=600,
            )
            if service_name is None and ctx.browser_e2e:
                validate_blazor_wasm_handoff(root)
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
    parser.add_argument("--browser-e2e", action="store_true")
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
    ctx.browser_e2e = args.mode == "full" or args.browser_e2e
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

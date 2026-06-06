#!/usr/bin/env python3
"""Create folder skeleton from PROJECT_STRUCTURE.md-like architecture rules."""

from __future__ import annotations

import argparse
from pathlib import Path

BASE_DIRS = [
    "src/Aspire/AppHost",
    "src/Aspire/ServiceDefaults",
    "src/FrontEnd/Web",
    "src/FrontEnd/Web.Client",
    "src/BackEnd/APIGateway",
    "src/BackEnd/BuildingBlocks/Contracts",
    "src/BackEnd/BuildingBlocks/Messaging",
    "src/BackEnd/BuildingBlocks/Observability",
    "test/Architecture",
    "test/Unit",
    "test/Integration",
    "test/Contract",
    "test/Functional/APIGateway",
    "test/Functional/FrontEnd",
    "test/EndToEnd",
]

SERVICE_LAYERS = {
    "Domain": [
        "Aggregates",
        "Entities",
        "ValueObjects",
        "Events",
        "Repositories",
    ],
    "Application": [
        "Abstractions",
        "UseCases/Commands",
        "UseCases/Queries",
        "DTOs",
        "Validators",
    ],
    "Infrastructure": [
        "Persistence/Configurations",
        "Persistence/Migrations",
        "Repositories",
        "Integrations",
    ],
    "Api": [
        "Endpoints",
        "Mapping",
    ],
    "Contracts": [
        "Requests",
        "Responses",
        "IntegrationEvents",
    ],
}

TEST_SERVICE_DIRS = [
    "test/Unit/Services/{service}",
    "test/Integration/Services/{service}",
    "test/Contract/Services/{service}",
]

PROJECT_README = """# Project Structure

This project structure was created by `project-structure-setup`.

## Baseline Folders

- `src/Aspire/AppHost`
- `src/Aspire/ServiceDefaults`
- `src/FrontEnd/Web`
- `src/FrontEnd/Web.Client`
- `src/BackEnd/APIGateway`
- `src/BackEnd/BuildingBlocks/Contracts`
- `src/BackEnd/BuildingBlocks/Messaging`
- `src/BackEnd/BuildingBlocks/Observability`
- `test/Architecture`
- `test/Unit`
- `test/Integration`
- `test/Contract`
- `test/Functional/APIGateway`
- `test/Functional/FrontEnd`
- `test/EndToEnd`

## Workflow

Run `project-structure-setup` before `task-agents`.

After this baseline exists, `task-agents` can route work through workflow guardrails, intake planning, implementation coordination, specialist analysis, serial implementation, review, verification, and explicit git operations.
"""


def _normalize_name(value: str) -> str:
    return value.strip().replace(" ", "")


def _prompt_project_name() -> str:
    while True:
        try:
            value = input("프로젝트 이름(ProjectName)을 입력해 주세요: ").strip()
        except EOFError:
            raise SystemExit("--project-name is required when --project-name is not provided.")
        if value:
            return value
        print("Project name cannot be empty. Please enter again.")


def _prompt_service_name() -> str | None:
    try:
        value = input("서비스 이름(ServiceName)을 입력해 주세요(비우면 서비스 생성 생략): ").strip()
    except EOFError:
        return None
    if not value:
        return None
    return value


def _service_dirs(service: str) -> list[str]:
    root = f"src/BackEnd/Services/{service}"
    paths = [root]
    for layer, subs in SERVICE_LAYERS.items():
        layer_root = f"{root}/{service}.{layer}"
        paths.append(layer_root)
        for sub in subs:
            paths.append(f"{layer_root}/{sub}")
    for test_root in TEST_SERVICE_DIRS:
        paths.append(test_root.format(service=service))
    return paths


def collect_dirs(base_root: Path, project_name: str | None, service_name: str | None) -> list[Path]:
    target_root = base_root
    if project_name:
        target_root = base_root / project_name

    dirs = [target_root / p for p in BASE_DIRS]
    dirs.append(target_root / "docs/Project")
    if service_name:
        dirs.extend([target_root / p for p in _service_dirs(service_name)])
    return dirs


def ensure_gitkeep(path: Path) -> None:
    marker = path / ".gitkeep"
    if not marker.exists():
        marker.write_text("")


def ensure_project_readme(target_root: Path, preview: bool) -> None:
    readme = target_root / "docs/Project/README.md"
    if preview:
        print(f"[preview] {readme}")
        return
    if readme.exists():
        print(f"[exists] {readme}")
        return
    readme.parent.mkdir(parents=True, exist_ok=True)
    readme.write_text(PROJECT_README, encoding="utf-8")
    print(f"[create] {readme}")


def run(base_root: Path, project_name: str | None, service_name: str | None, preview: bool, no_gitkeep: bool) -> None:
    target_root = base_root / project_name if project_name else base_root
    for dir_path in collect_dirs(base_root, project_name, service_name):
        if preview:
            print(f"[preview] {dir_path}")
            continue

        created = dir_path.exists()
        dir_path.mkdir(parents=True, exist_ok=True)
        if created:
            print(f"[exists] {dir_path}")
        else:
            print(f"[create] {dir_path}")

        if not no_gitkeep:
            ensure_gitkeep(dir_path)

    ensure_project_readme(target_root, preview)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create architecture folders with variable project and service names")
    parser.add_argument("--root", default=".", help="Base path where structure is created")
    parser.add_argument("--project-name", help="Project folder name")
    parser.add_argument("--service-name", help="Optional service name")
    parser.add_argument("--preview", action="store_true", help="Print target directories only")
    parser.add_argument("--no-gitkeep", action="store_true", help="Do not create .gitkeep files")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    root = Path(args.root).resolve()

    project_name = _normalize_name(args.project_name) if args.project_name else None
    if not project_name:
        project_name = _normalize_name(_prompt_project_name())

    service_name = _normalize_name(args.service_name) if args.service_name else None
    if service_name is None:
        prompted_service = _prompt_service_name()
        service_name = _normalize_name(prompted_service) if prompted_service else None

    if project_name == "":
        raise SystemExit("--project-name cannot be empty")
    if service_name == "":
        raise SystemExit("--service-name cannot be empty")

    run(root, project_name, service_name, preview=args.preview, no_gitkeep=args.no_gitkeep)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

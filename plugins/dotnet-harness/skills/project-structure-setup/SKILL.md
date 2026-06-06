---
name: project-structure-setup
description: Scaffold a .NET 10 Aspire Clean Architecture project at the current project root after collecting a project name.
---

# Project Structure Setup

Use when creating/recreating the default .NET 10 project baseline.

## What it builds

- `src/Aspire/{AppHost,ServiceDefaults}`
- `src/FrontEnd/{Web,Web.Client}`
- `src/BackEnd/APIGateway`
- `src/BackEnd/BuildingBlocks/{Application,Contracts,Messaging,Observability,Persistence}`
- `test/{Architecture,Unit,Integration,Contract,Functional/{APIGateway,FrontEnd},EndToEnd}`
- `docs/Project/README.md` with the baseline structure summary
- repo-local Codex harness files (`AGENTS.md`, `.codex/agents`, `.codex/scripts`) when available
- no repo-local `.codex/skills`; skills are provided by the `dotnet-harness:*` plugin
- .NET 10 skeleton files for Aspire, Minimal API, YARP, Scalar, EF Core, Redis, Blazor Auto, MudBlazor, and mediator-like dispatch

## Service scaffold (optional)

If `{ServiceName}` enabled:

- `src/BackEnd/Services/{ServiceName}/{ServiceName}.{Domain,Application,Infrastructure,Api,Contracts}`
- `test/{Unit,Integration,Contract}/Services/{ServiceName}`

## Prompts

- Always collect `ProjectName` when `--project-name` is omitted.
- Use `ProjectName` as project metadata only; scaffold folders at the current project root.
- Prompts interactive when `--project-name` or `--service-name` omitted.
- User-facing prompt text is Korean.
- If `ProjectName` empty, request again.
- If `ServiceName` empty, skip service folders.

## CLI

```bash
python scripts/bootstrap_project_structure.py --root .
python scripts/bootstrap_project_structure.py --root . --service-name Orders
python scripts/bootstrap_project_structure.py --root . --project-name MyProj
python scripts/bootstrap_project_structure.py --root . --project-name MyProj --service-name Orders --preview
python scripts/bootstrap_project_structure.py --root . --project-name MyProj --harness-only
```

## Rules

- Create directories, `.gitkeep` files, and baseline .NET skeleton files.
- Create `docs/Project/README.md` if it does not exist.
- Install repo-local Codex harness files into the target project root if source files exist.
- Use `--harness-only` to install `AGENTS.md` and `.codex` harness files without creating `src`, `test`, or `docs/Project` structure.
- `.gitkeep` enabled by default; use `--no-gitkeep` to skip.
- Never delete existing directories.
- Do not overwrite an existing `docs/Project/README.md`.
- Do not overwrite existing Codex harness files.
- Do not overwrite existing source or project files.

See [scripts/bootstrap_project_structure.py](scripts/bootstrap_project_structure.py) and [references/project-structure.md](references/project-structure.md).

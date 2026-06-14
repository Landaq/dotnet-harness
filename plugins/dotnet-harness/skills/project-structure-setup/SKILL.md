---
name: project-structure-setup
description: Scaffold a .NET 10 Aspire Clean Architecture project at the current project root after collecting a project name.
---

# Project Structure Setup

Use when creating/recreating default .NET 10 baseline.

## What it builds

- `src/Aspire/{AppHost,ServiceDefaults}`
- `src/FrontEnd/{Web,Web.Client}`
- `src/BackEnd/APIGateway`
- `src/BackEnd/BuildingBlocks/{Application,Contracts,Messaging,Observability,Persistence}`
- `test/{Architecture,Unit,Integration,Contract,Functional/{APIGateway,FrontEnd},EndToEnd}`
- `docs/Project/README.md` with the baseline structure summary
- repo-local Codex harness (`AGENTS.md`, `.codex/agents`, `.codex/scripts`) when available
- no repo-local `.codex/skills`; use `dotnet-harness:*` plugin skills
- .NET 10 skeleton: Aspire, Minimal API, YARP, Scalar, EF Core, Redis, Blazor Auto, MudBlazor, mediator-like dispatch
- package versions are generated from `references/package-versions.json`
- Project policy override: create `.codex/harness-config.json` when missing so later Task Agents routing can read UI defaults; setup still emits the default stack unless a future scaffold option explicitly changes templates.

## Service scaffold (optional)

If `{ServiceName}` enabled:

- `src/BackEnd/Services/{ServiceName}/{ServiceName}.{Domain,Application,Infrastructure,Api,Contracts}`
- `test/{Unit,Integration,Contract}/Services/{ServiceName}`

## Prompts

- Always collect `ProjectName` when `--project-name` omitted.
- `ProjectName` = metadata only; scaffold at current project root.
- Interactive prompts when `--project-name` or `--service-name` omitted.
- User-facing prompt text is Korean.
- If `ProjectName` empty, request again.
- If `ServiceName` empty, skip service folders.
- Use `-NoService` or `--no-service` for non-interactive automation when no service scaffold should be created.

## CLI

Prefer PowerShell wrapper: UTF-8 + Windows launch safer.

```powershell
pwsh -NoProfile -File install.ps1 -Root .
pwsh -NoProfile -File install.ps1 -Root . -ServiceName Orders
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj -NoService
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj -ServiceName Orders -Preview
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj -HarnessOnly
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj -HarnessOnly -SkipHarnessUpgrade
```

## Rules

- Create dirs, `.gitkeep`, baseline .NET skeleton.
- Treat Clean Architecture, DDD, MudBlazor, SQL Server, Redis, YARP, and Scalar as the default scaffold profile, not a universal policy for every target repo.
- Create `docs/Project/README.md` if it does not exist.
- Install repo-local Codex harness into target root if source exists.
- Use `--harness-only` to install `AGENTS.md` and `.codex` harness files without creating `src`, `test`, or `docs/Project` structure.
- Re-running `install.ps1` against a project that already has `AGENTS.md`, `.codex/agents`, `.codex/scripts`, or legacy `.codex/skills` triggers backup-based harness upgrade before scaffold work.
- Use `-SkipHarnessUpgrade` only when stale repo-local harness files must intentionally remain untouched.
- `.gitkeep` enabled by default; use `--no-gitkeep` to skip.
- Never delete existing directories.
- Do not overwrite an existing `docs/Project/README.md`.
- The bootstrap script does not overwrite existing Codex harness files by itself; `install.ps1` uses the explicit upgrade script for existing harness refresh.
- Do not overwrite existing source or project files.
- Update `references/package-versions.json` instead of editing package versions inline in the bootstrap script.

See [scripts/bootstrap_project_structure.py](scripts/bootstrap_project_structure.py) and [references/project-structure.md](references/project-structure.md).

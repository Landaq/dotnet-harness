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
- Aspire AppHost SDK and NuGet package versions are generated from `references/package-versions.json`
- Project policy override: create `.codex/harness-config.json` when missing so later Task Agents routing can read UI defaults; setup still emits the default stack unless a future scaffold option explicitly changes templates.

## Service scaffold (optional)

If `{ServiceName}` enabled:

- `src/BackEnd/Services/{ServiceName}/{ServiceName}.{Domain,Application,Infrastructure,Api,Contracts}`
- `test/{Unit,Integration,Contract}/Services/{ServiceName}` with buildable test projects

## Prompts

- Collect `ProjectName` when `--project-name` is omitted, except for `--harness-only`.
- `ProjectName` = metadata only; scaffold at current project root.
- Interactive prompts when `--project-name` or `--service-name` omitted.
- User-facing prompt text is Korean.
- If `ProjectName` empty, request again.
- If `ServiceName` empty, skip service folders.
- Reject names containing traversal, path separators, quotes, or control characters before creating files.
- `ServiceName` must be a valid ASCII C# identifier after spaces are removed.
- Limit `ProjectName` to 120 characters and `ServiceName` to 64 characters so generated filename components remain portable.
- Normalize generated Aspire resource names to start with an ASCII letter, collapse repeated hyphens, and remain within 64 characters.
- Use `-NoService` or `--no-service` for non-interactive automation when no service scaffold should be created.

## CLI

Select the wrapper for the host OS. Use PowerShell on Windows:

```powershell
pwsh -NoProfile -File install.ps1 -Root .
pwsh -NoProfile -File install.ps1 -Root . -ServiceName Orders
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj -NoService
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj -ServiceName Orders -Preview
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj -HarnessOnly
pwsh -NoProfile -File install.ps1 -Root . -ProjectName MyProj -HarnessOnly -SkipHarnessUpgrade
```

Use zsh on macOS:

```zsh
./install.zsh --root .
./install.zsh --root . --service-name Orders
./install.zsh --root . --project-name MyProj
./install.zsh --root . --project-name MyProj --no-service
./install.zsh --root . --project-name MyProj --service-name Orders --preview
./install.zsh --root . --project-name MyProj --harness-only
./install.zsh --root . --project-name MyProj --harness-only --skip-harness-upgrade
```

## Rules

- Create dirs, `.gitkeep`, baseline .NET skeleton.
- Treat Clean Architecture, DDD, MudBlazor, SQL Server, Redis, YARP, and Scalar as the default scaffold profile, not a universal policy for every target repo.
- Create `docs/Project/README.md` if it does not exist.
- Install repo-local Codex harness into target root if source exists.
- Use `--harness-only` to install `AGENTS.md` and `.codex` harness files without creating `src`, `test`, or `docs/Project` structure.
- Re-running the platform install wrapper against a project that already has `AGENTS.md`, `.codex/agents`, `.codex/scripts`, or legacy `.codex/skills` triggers backup-based harness upgrade before scaffold work.
- Resolve and validate scaffold options before that upgrade so invalid names or unsupported service reruns leave the existing harness unchanged.
- Use `-SkipHarnessUpgrade` on Windows or `--skip-harness-upgrade` on macOS only when stale repo-local harness files must intentionally remain untouched.
- `.gitkeep` enabled by default; use `--no-gitkeep` to skip.
- Never delete existing directories.
- Fail before writing when a service is requested for an existing no-service scaffold; add services through the task workflow so AppHost, gateway, and solution wiring are updated together.
- Do not overwrite an existing `docs/Project/README.md`.
- The bootstrap script does not overwrite existing Codex harness files by itself; the platform install wrapper uses the shared upgrade core for existing harness refresh.
- Do not overwrite existing source or project files.
- Update `references/package-versions.json` instead of editing the Aspire AppHost SDK or NuGet package versions inline in the bootstrap script.

See [scripts/bootstrap_project_structure.py](scripts/bootstrap_project_structure.py) and [references/project-structure.md](references/project-structure.md).

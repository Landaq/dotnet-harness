# Dotnet Harness Plugin

Versioned .NET 10 harness for repo-local skills, agents, scripts, and project setup.

## Contains

- `skills/`: plugin-discovered Codex skills.
- `assets/harness/AGENTS.md`: project bootstrap rules.
- `assets/harness/.codex/agents`: task routing agents.
- `assets/harness/.codex/scripts`: helper scripts and validation wrappers.

`skills/` is the single source for skill content. Install and upgrade scripts copy
it into target projects as `.codex/skills`.

## Migration

Use `project-structure-setup` from this plugin to scaffold an existing project root.
It keeps `ProjectName` input as metadata, creates folders at the target root, and
installs the harness without overwriting existing files. The default setup creates
.NET 10 Aspire, Clean Architecture, DDD, Minimal API, YARP, Blazor Auto,
MudBlazor, Scalar, SQL Server, and Redis skeleton files.

Harness-only install:

```powershell
pwsh -NoProfile -File install.ps1 -Root "C:\path\to\project" -ProjectName ExistingProject -HarnessOnly
```

Default .NET project setup:

```powershell
pwsh -NoProfile -File install.ps1 -Root "C:\path\to\project" -ProjectName NewProject
```

Upgrade existing harness with backup:

```powershell
pwsh -NoProfile -File assets\harness\.codex\scripts\upgrade-harness.ps1 -TargetRoot "C:\path\to\project" -Apply
```

Use the PowerShell wrappers instead of calling Python scripts directly. The
wrappers set UTF-8 mode and avoid Windows sandbox runner process-creation issues.

## Validation

```powershell
pwsh -NoProfile -File .codex\scripts\validate-task-agents.ps1
```

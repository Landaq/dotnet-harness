# Dotnet Harness Plugin

Versioned .NET 10 harness for plugin skills, repo-local agents, scripts, and project setup.

## Contains

- `skills/`: plugin-discovered Codex skills. Use this as the versioned source
  for setup, workflow routing, UI policy, service boundaries, TDD, and audits.
- `assets/harness/AGENTS.md`: project bootstrap rules. Use this to make target
  repositories route work through the local harness without hardcoding a project
  name.
- `assets/harness/.codex/agents`: task routing agents. Use these for specialized
  goal boundary, planning, implementation, review, verification, and git stages.
- `assets/harness/.codex/scripts`: helper scripts and validation wrappers. Use
  these from PowerShell so UTF-8 mode and Windows process-launch behavior stay
  predictable.
- `scripts/validate-release.ps1`: plugin release gate. Use this before tagging a
  release to validate the manifest, harness agents, all skills, packaging
  hygiene, and whitespace.
- `.mcp.json`: Context7 MCP configuration. Use this only when current external
  library/framework/API documentation is needed for implementation, review, or
  verification.

`skills/` is the single source for skill content and is discovered through the
plugin as `dotnet-harness:*`. Install and upgrade scripts do not copy skills into
target projects because repo-local `.codex/skills` duplicates plugin skills in
Codex discovery.

## Migration

Use `project-structure-setup` from this plugin to scaffold an existing project root.
It keeps `ProjectName` input as metadata, creates folders at the target root, and
installs the harness without overwriting existing files. The default setup creates
.NET 10 Aspire, Clean Architecture, DDD, Minimal API, YARP, Blazor Auto,
MudBlazor, Scalar, SQL Server, and Redis skeleton files.

Use project setup before Task Agents on a new repository because Task Agents
depend on `src/`, `test/`, and `docs/Project/README.md` as baseline anchors.

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

Use upgrade when a project already has `.codex` harness files. The script backs
up existing harness files, replaces active agents/scripts from this plugin,
removes repo-local `.codex/skills` after backup, creates missing `.gitignore` and
`.gitattributes`, and renames backup agent/skill discovery files to `.bak` so
Codex does not load stale duplicates.

Task Result reports are opt-in:

```powershell
pwsh -NoProfile -File .codex\scripts\write-task-result.ps1 -Summary "short-summary" -Request "..." -Work "..." -Result "..." -Todo "..."
```

Use Task Result only when a visible HTML work summary is explicitly requested.
Normal Task Agents runs do not create result files by default.

Use the PowerShell wrappers instead of calling Python scripts directly. The
wrappers set UTF-8 mode and avoid Windows sandbox runner process-creation issues.

## Validation

Release validation:

```powershell
pwsh -NoProfile -File scripts\validate-release.ps1
```

Use this before commit, tag, or release. It is the preferred single command for
plugin packaging checks, including the rule that harness assets must not include
repo-local `.codex/skills`.

Repo-local harness validation after install or upgrade:

```powershell
pwsh -NoProfile -File .codex\scripts\validate-task-agents.ps1
```

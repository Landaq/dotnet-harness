# Dotnet Harness Plugin

Versioned .NET 10 harness for plugin skills, repo-local agents, scripts, and project setup.

## Contains

- `skills/project-structure-setup`: plugin-discovered setup skill and scaffold
  script source.
- `skills/task-agents`: plugin-discovered workflow routing skill. Domain
  policies for UI, service boundaries, TDD, guardrails, and audits live under
  `skills/task-agents/references` instead of separate top-level skills.
- `assets/harness/AGENTS.md`: project bootstrap rules. Use this to make target
  repositories route work through the local harness without hardcoding a project
  name.
- `assets/harness/.codex/agents`: task routing agents. Use these for specialized
  goal boundary, planning, implementation, review, verification, and git stages.
- `assets/harness/.codex/agent-categories/index.html`: self-contained catalog of
  Luna, Sol, and Terra agent assignments and reasoning effort.
- `assets/harness/.codex/scripts`: helper scripts and validation wrappers. Use
  these from PowerShell so UTF-8 mode and Windows process-launch behavior stay
  predictable.
- `scripts/validate-release.ps1`: plugin release gate. Use this before tagging a
  release to validate the manifest, harness agents, all skills, packaging
  hygiene, and whitespace.
- `.mcp.json`: Context7 MCP configuration. Use this only when current external
  library/framework/API documentation is needed for implementation, review, or
  verification.

The only top-level plugin skills are `project-structure-setup` and
`task-agents`. Install and upgrade scripts do not copy skills into target
projects because repo-local `.codex/skills` duplicates plugin skills in Codex
discovery.

## Agent Model Catalog

Open `.codex/agent-categories/index.html` in an installed harness to inspect the
model and reasoning-effort assignment for every agent. Category pages are static
documentation only. Runtime discovery remains flat at `.codex/agents/*.toml`,
and invocation uses each TOML file's `name`; no runtime agent definitions live
under `.codex/agent-categories`.

## Migration

Use `project-structure-setup` from this plugin to scaffold an existing project root.
It keeps `ProjectName` input as metadata, creates folders at the target root, and
installs the harness without overwriting existing files. The default setup creates
.NET 10 Aspire, Clean Architecture, DDD, Minimal API, YARP, Blazor Auto,
MudBlazor, Scalar, SQL Server, and Redis skeleton files.

Use project setup before Task Agents on a new repository because Task Agents
depend on `src/`, `test/`, and `docs/Project/README.md` as baseline anchors.
For 0.5.0 upgrade notes, read `MIGRATION.md` before applying an existing harness
upgrade.

## Workflow Modes

Task Agents choose one mode before routing:

- `lightweight`: quick path for trivial or small tasks. Phase contracts stay
  internal, Phase 5 workers are not used, and the final report stays concise.
- `standard`: default path for non-trivial work. Phase 0-8 applies, subagent
  delegation is used when the active runtime exposes and authorizes it,
  and Phase 5 workers are considered only for settled slices.
- `deep`: release, scaffold, architecture, high-risk, or explicitly requested
  path. Socratic clarification, full handoff gates, review, and verification are
  stricter.

Phase 5 workers (`backend-worker`, `frontend-worker`, `test-worker`, and
`docs-harness-worker`) run only in `standard` or `deep`. Parallel read-only
specialists and Phase 5 workers are preferred when write sets, contracts,
package/solution files, runtime state, and validation evidence are independent.
Agents are skipped for user preference only on explicit opt-out wording such as
`에이전트 쓰지마`, `no agents`, `메인에서 직접 해줘`, or `직접 해줘`; Task Result
reports and git operations remain explicit-only.

For non-trivial work, subagent and safe parallel-agent execution is preferred
when the host/runtime makes delegation available. Some hosts require explicit
authorization before delegation. Direct main-thread execution is used for
trivial work, unavailable or unauthorized subagent tooling, or opt-out wording
such as `에이전트 쓰지마`, `no agents`, `skip agents`, `직접 해줘`, or
`메인에서 직접 해줘`, or `main thread only`.

Current scaffold baseline: setup creates .NET project files, solution entries,
Unit/Architecture/APIGateway Functional xUnit smoke tests, and optional
`ServiceName` AppHost/Gateway integration. Scaffold consumers should still run
the generated solution build/test smoke checks before treating the target project
as ready for feature work. `ServiceName` is an initial-scaffold option; 0.5.0
fails before writing when a service is supplied on a rerun of an existing
no-service scaffold, because safe structured merging is not yet supported.

Project policy overrides: setup creates `.codex/harness-config.json` when it is
missing. Task Agents inspect that file before UI work. Keys such as
`ui.defaultLibrary`, `ui.biLibrary`, and `ui.devExpressVersion` override the
default MudBlazor/DevExpress guidance for that target repo. The setup scaffold
still emits the default stack unless a future scaffold option explicitly changes
templates.

Release version helper:

```powershell
pwsh -NoProfile -File scripts\release-helper.ps1 -Version 0.5.0 -Apply
```

Release validation checks that `plugin.json` and `VERSION.md` agree.
Default release validation is quick and skips generated .NET restore/build/test:

```powershell
pwsh -NoProfile -File scripts\validate-release.ps1
```

macOS uses its native zsh entrypoint. It selects Python 3.11 or newer and uses
an isolated uv environment for release-only Python dependencies:

```zsh
./scripts/validate-release.zsh --mode Quick
```

Run full validation before scaffold/template/package releases. `Full` restores,
builds, and tests generated solutions, then uses Playwright Chromium to verify
that Blazor `InteractiveAuto` remains interactive after server interactivity is
blocked on a second load:

```powershell
pwsh -NoProfile -File scripts\validate-release.ps1 -Mode Full
pwsh -NoProfile -File scripts\validate-release.ps1 -Mode Scaffold
```

Install the browser once before local `Full` validation:

```powershell
python -m pip install -r scripts\validation\requirements.txt
python -m playwright install chromium
```

GitHub Actions runs the same `Full` contract on native `windows-latest` and
`macos-latest` runners. Codex system validators remain a required local check;
CI skips only those host-provided validators because they are not installed on
standard GitHub runners.

Available validation goals are `Core`, `Harness`, `Scaffold`, `Upgrade`, and
`Whitespace`. Use `-BrowserE2E` or `--browser-e2e` with `Scaffold` to opt into
the browser handoff check without running every `Full` validation group.

Harness-only install:

```powershell
pwsh -NoProfile -File install.ps1 -Root "C:\path\to\project" -ProjectName ExistingProject -HarnessOnly
```

```zsh
./install.zsh --root "/path/to/project" --project-name ExistingProject --harness-only
```

When the target already has `AGENTS.md`, `.codex\agents`, `.codex\scripts`, or
legacy `.codex\skills`, `install.ps1` first runs the backup-based harness
upgrade path. Pass `-SkipHarnessUpgrade` only when stale repo-local harness files
must intentionally remain untouched.

Default .NET project setup:

```powershell
pwsh -NoProfile -File install.ps1 -Root "C:\path\to\project" -ProjectName NewProject
```

```zsh
./install.zsh --root "/path/to/project" --project-name NewProject
```

Upgrade existing harness with backup:

```powershell
pwsh -NoProfile -File assets\harness\.codex\scripts\upgrade-harness.ps1 -TargetRoot "C:\path\to\project" -Apply
```

```zsh
./assets/harness/.codex/scripts/upgrade-harness.zsh --target-root "/path/to/project" --apply
```

Use upgrade when a project already has `.codex` harness files. The script backs
up existing harness files, transactionally replaces active agents/scripts,
removes repo-local `.codex/skills` after backup, creates missing `.gitignore` and
`.gitattributes`, and renames backup agent/skill discovery files to `.bak` so
Codex does not load stale duplicates. Failed apply or validation restores the
pre-upgrade state while retaining the backup for diagnosis.

Task Result reports are opt-in:

```powershell
pwsh -NoProfile -File .codex\scripts\write-task-result.ps1 -Summary "short-summary" -Request "..." -Work "..." -Result "..." -Todo "..."
```

Use Task Result only when a visible HTML work summary is explicitly requested.
Normal Task Agents runs do not create result files by default. Older result
files are moved to `docs/TaskResult/archive` instead of being deleted; pass
`-NoPrune` only when the user explicitly wants every report to stay in the
active folder.

Use PowerShell wrappers on Windows and zsh wrappers on macOS instead of calling
the shared Python cores directly. Each platform wrapper resolves its runtime and
maps native command-line options to the same behavior.

The model catalog is documentation only. Runtime agents remain flat, and their
effective sandbox is also bounded by the parent session permissions supported by
the active host.

## Validation

Release validation:

```powershell
pwsh -NoProfile -File scripts\validate-release.ps1
```

```zsh
./scripts/validate-release.zsh --mode Quick
```

Use this before commit, tag, or release. It is the preferred single command for
plugin packaging checks, including the rule that harness assets must not include
repo-local `.codex/skills`.

Repo-local harness validation after install or upgrade:

```powershell
pwsh -NoProfile -File .codex\scripts\validate-task-agents.ps1
```

```zsh
./.codex/scripts/validate-task-agents.zsh --repo-root .
```

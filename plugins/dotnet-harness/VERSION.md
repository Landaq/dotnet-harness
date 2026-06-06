# Version

Current version: `0.4.0`

## Release Notes

### 0.4.0

- Add `goal-boundary` agent to separate goal, scope, non-goals, success criteria,
  deliverables, and stop conditions before intake planning.
- Reorder harness agents so goal-boundary runs after workflow guardrails and
  before planning/implementation coordination.
- Tighten Task Agents routing and validation around the expanded agent set.

### 0.3.0

- Rename plugin to `dotnet-harness`.
- Make .NET 10 stack skeleton part of default setup.
- Add Aspire, Clean Architecture, DDD, Minimal API, YARP, Blazor Auto,
  MudBlazor, Scalar, SQL Server, and Redis project contracts.

### 0.2.0

- Add `--harness-only` install mode.
- Add backup-based `upgrade-harness.ps1` automation.
- Document existing-project upgrade flow.
- Remove duplicated skill payload from harness assets; plugin `skills/` is the source.

### 0.1.0

- Package repo-local Codex skills.
- Package task agents and helper scripts as harness assets.
- Include project setup, TaskResult, validation, and migration helpers.

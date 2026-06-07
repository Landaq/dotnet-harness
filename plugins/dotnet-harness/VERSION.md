# Version

Current version: `0.4.11`

## Release Notes

### 0.4.11

- Reduce Task Agents to a lightweight entrypoint and move detailed workflow,
  phase, delegation, worker, git, and TaskResult policies into references.
- Consolidate guardrail, service-template, frontend UI, TDD, and reference-audit
  helper skills into `task-agents/references/domain-policies.md`.
- Keep only `project-structure-setup` and `task-agents` as top-level plugin
  skills.
- Update harness agents to use `dotnet-harness:task-agents` domain policy
  references instead of deleted helper skill contracts.
- Strengthen release validation for split Task Agents references and structured
  workflow-mode policy checks.

### 0.4.10

- Split Task Agents workflow into explicit phases with assigned agents,
  purpose, input contract, output contract, handoff gate, and next phase.
- Require previous agent results to be explicit, bounded, and accepted before
  the next phase handoff.
- Require handoff prompts to start from accepted prior results instead of raw
  ambiguous agent output.
- Compress dotnet-harness skill instructions in caveman style while preserving
  validation-critical policy text.
- Strengthen task-agent and release validation for phase contracts and handoff
  gate requirements.

### 0.4.9

- Make agent-first handoff the default for non-trivial dotnet-harness work even
  when the user does not explicitly request subagent handoff.
- Treat `@dotnet-harness`, plugin/workflow mentions, and non-trivial backend,
  frontend, full-stack, refactoring, validation, or verification work as
  automatic Task Agents handoff triggers unless the user explicitly opts out.
- Add direct-main opt-out handling for phrases such as `에이전트 쓰지마` and
  `no agents` while keeping safety, validation, TaskResult, and git gates
  active.
- Require staged subagent outputs to become the input contract for the next
  handoff stage.
- Strengthen release and task-agent validation for automatic handoff, opt-out,
  TaskResult opt-in, and explicit git-operation reporting.

### 0.4.8

- Change Task Agents routing from agent-assisted review to agent-first
  orchestration for non-trivial work.
- Require main thread to act as orchestrator, not the default implementer, when
  task-agents is active.
- Add `/feedback` and agent-wide request triggers so feedback/code-review can be
  attached early instead of only after implementation.
- Require actual delegated-agent tool-call receipt evidence before counting
  subagent utilization as satisfied.
- Add Socratic answer reassessment: update goal boundary, recalculate ambiguity,
  and continue asking until the active goal is aligned and average ambiguity is
  8% or lower.
- Strengthen installed harness and release validation for agent-first routing,
  non-overlap rules, final agent result reporting, and TaskResult opt-in status.

### 0.4.7

- Add compressed internal subagent handoff rules using `caveman full` while
  keeping user-facing Socratic questions, approvals, risk warnings, and final
  responses clear.
- Pin Context7, OpenAI developer MCP, and caveman skill configuration blocks in
  harness agent TOML files.
- Add an optional bundled caveman skill payload and `ensure-caveman-skill.ps1`
  helper for opt-in installation when the user does not already have caveman.
- Add `--install-optional-skills` / `-InstallOptionalSkills` setup and upgrade
  paths without making optional skills a hard requirement.
- Strengthen validation so missing MCP, caveman, and optional skill helper
  wiring fails release checks.

### 0.4.6

- Add a Task Agents subagent utilization floor for non-trivial work.
- Require at least one pre-implementation specialist subagent and one
  post-implementation review or verification subagent when tooling is available.
- Require `Delegation: skipped` entries to include a concrete skip reason for
  every eligible role that was not spawned.
- Strengthen release validation so missing utilization-floor rules fail the
  release gate.

### 0.4.5

- Require a Socratic clarification checkpoint before Task Agents planning or
  implementation for non-trivial work.
- Allow skipping the checkpoint only for trivial/direct tasks or when the user
  already gave explicit scope, success criteria, validation, and approval.
- Require Task Agents output to report `Socratic` status so skipped
  clarification is visible.
- Strengthen release validation so missing Socratic checkpoint rules fail the
  release gate.

### 0.4.4

- Stop copying plugin skills into target repo-local `.codex/skills`.
- Back up and remove existing target `.codex/skills` during setup and upgrade to
  avoid duplicate Codex skill discovery.
- Point repo-local agents and `AGENTS.md` at `dotnet-harness:*` plugin skills.
- Move the Task Result Python helper into `.codex/scripts` so it no longer
  depends on repo-local skill folders.
- Update task agent validation and release validation for plugin-skill-only
  harness installs.
- Require Task Agents to use actual subagent delegation when tooling is
  available, with explicit fallback reporting when it is not.
- Make Task Result HTML generation opt-in instead of a default Task Agents
  completion step.
- Remove legacy `SKILL.original.md` files from the packaged plugin skills.
- Prevent backup skills from being discovered as duplicate active skills during
  harness upgrade.
- Rename backup agent `.toml` files and backup skill `SKILL.md` files to `.bak`
  only inside harness backup discovery paths before validation.
- Add `scripts/validate-release.ps1` as the release validation entrypoint.
- Document why each plugin feature exists and when to use it.

### 0.4.3

- Create missing `.gitignore` and `.gitattributes` during harness upgrade.
- Prevent backup agents from being discovered as duplicate active agents.
- Replace active harness agent/skill/script directories from the source harness
  after backup so stale files do not remain active.

### 0.4.2

- Add Context7 MCP companion configuration to the plugin.
- Generate `.gitignore` and `.gitattributes` during project setup.
- Strengthen Socratic requirement clarification with feature goals, ambiguity
  scoring, an 8% average ambiguity gate, and safe parallelization criteria.

### 0.4.1

- Fix generated scaffold build references.
- Align Aspire AppHost SDK and hosting package versions with restoreable packages.
- Add missing ASP.NET Core, OpenAPI, WebAssembly, and DI abstraction references
  needed for scaffold-first `dotnet build {ProjectName}.slnx`.

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

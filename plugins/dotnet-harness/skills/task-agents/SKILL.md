---
name: task-agents
description: Route project work through discovered repo-local task agents and dotnet-harness plugin skills in workflow order. Use when a request needs staged specialist handling, such as architecture planning, backend service boundaries, frontend UI policy, TDD sequencing, reference audits, or any multi-step implementation/review workflow. This skill must discover project names, solution files, agents, and plugin skills instead of hardcoding them.
---

# Task Agents

Use: coordinate repo-local specialist agents. No hardcoded project/solution/path beyond standard discovery.

## Discovery First

Before route, inspect repo:

1. List `.codex/agents/*.toml`; read each `name`, `description`, `developer_instructions` summary.
2. Use `dotnet-harness:*` plugin skills as the skill source. Do not require or create repo-local `.codex/skills`.
3. Detect project structure anchors from `src/`, `test/`, and `docs/Project/README.md`; also detect solution anchors from `*.slnx` and `*.sln`.
4. Treat missing agents/skills as routing constraints, not fatal errors. Report missing capability; continue closest available workflow.

No repo identity hardcode. Use discovered solution, folders, agents, skill names.

## Workflow Modes

Select one workflow mode before routing:

- `lightweight`: default for trivial or small tasks.
- `standard`: default for non-trivial work.
- `deep`: use when the user explicitly asks for deep review/planning, release, scaffold, architecture, or high-risk work.

Read `references/workflow-modes.md` when mode selection, ambiguity reporting, or mode-specific final reporting matters.

## Routing Core

Run stages in order unless the user narrows the task:

1. Requirement Intake.
2. Socratic Clarification.
3. Ambiguity Recalculation.
4. Goal Boundary Confirmation.
5. Agent Route Planning.
6. Subagent Handoff.
7. Worker Implementation.
8. Review Agent.
9. Verification Agent.
10. Main Thread Final Summary.

Read `references/phase-contracts.md` for full phase, Socratic, routing, output, and handoff gate contracts.

## Delegation Core

Task Agents must clarify before delegating. Actual subagent execution begins only after Socratic goal clarification is satisfied and runtime delegation permission is present.

Treat `$dotnet-harness`, `task-agents`, `/feedback`, `에이전트`, `subagent`, `서브에이전트`, `에이전트에게 맡겨`, or `작업을 에이전트들이 수행` as explicit authorization for actual subagent execution after clarification.

When the user asks for implementation, refactoring, review, or validation without agent wording, check runtime policy before spawning. If host/runtime policy requires explicit authorization, do not spawn; ask briefly whether to delegate to agents, or report `Delegation: skipped no-explicit-agent-request` and proceed main-thread direct after clarification.

Do not spawn worker subagents before Socratic clarification is satisfied and average ambiguity is `<= 8%`. Read-only clarification helpers such as `goal-boundary` or `intake-planner` also require runtime policy permission.

Read `references/delegation-policy.md` before spawning or skipping subagents, reporting delegation evidence, using structured handoffs, or applying the subagent utilization floor.

## Worker Core

Before assigning specialists or workers for non-trivial multi-area work, route through `feature-slicer` when available. Feature slices must define purpose, allowed paths, forbidden paths, dependency order, parallel eligibility, validation evidence, and stop condition.

Use feature-scoped specialists when a slice needs domain-specific planning before worker handoff:

- `service-template`: backend/API/domain/infrastructure/service slice.
- `frontend-ui`: Blazor/UI/client/rendering slice.
- `tdd-test`: test/validation/regression slice.
- `reference-auditor`: external reference or architecture comparison slice.
- `docs-harness-specialist`: plugin/skill/agent/script/scaffold/install/upgrade/docs slice.

Worker agents are `standard`/`deep` only. Do not call `backend-worker`, `frontend-worker`, `test-worker`, or `docs-harness-worker` in `lightweight`.

Read `references/feature-slicing-policy.md` and `references/worker-policy.md` before assigning feature slices, deciding `Parallel: yes` or `Parallel: no`, or writing specialist/worker handoffs.

## Review Core

Review agents are feature-slice scoped. Do not route a single reviewer over the whole diff unless the work is truly one slice or a cross-slice contract must be reviewed.

Prefer the smallest relevant reviewer set:

- `code-reviewer`: broad defect scan for a completed meaningful diff.
- `backend-reviewer`: backend, API, domain, EF, Aspire, YARP, SQL, Redis, or service slice.
- `frontend-reviewer`: Blazor, Web.Client, MudBlazor, UI state, rendering, or component slice.
- `test-reviewer`: test coverage, validation evidence, regression surface, or smoke command slice.
- `docs-harness-reviewer`: plugin, skill, agent, script, scaffold, install, upgrade, README, or release slice.

Read `references/review-policy.md` before assigning reviewer perspectives or parallel review groups.

## Domain Policies

Read `references/domain-policies.md` when a route needs workflow guardrails, backend service boundaries, frontend UI policy, TDD/test policy, or reference-comparison audit rules.

## Git And TaskResult

Git work is explicit-only. TaskResult remains opt-in only.

Read `references/task-result-and-git.md` before git operations, final reporting, or TaskResult artifact creation.

## Documentation Grounding

Use Context7 MCP only when implementation, review, audit, or verification depends on current external library/framework/API documentation.

Before querying:

1. Inspect local files first to discover package names, target framework, versions, and affected APIs.
2. Name the exact library/framework and one focused question the docs must answer.
3. Query the smallest relevant topic; avoid broad best-practice searches.
4. Tie the documentation result back to a local decision, file, command, or risk.

Do not use Context7 for repo-local routing, approval gates, generic architecture opinions, style preferences, or decisions already defined by local skills/agents.

## Dry-Run Validation

After changing agents or this skill, run:

```powershell
pwsh -NoProfile -File .codex/scripts/validate-task-agents.ps1
```

On macOS, run the platform validator instead:

```zsh
./.codex/scripts/validate-task-agents.zsh --repo-root .
```

If the script is unavailable, verify manually:

1. `.codex/agents` contains expected workflow agents.
2. Agent files expose `name`, `description`, `developer_instructions`, `model_reasoning_effort`, `sandbox_mode`.
3. No repo identity hardcoding remains in `.codex/agents`, `task-agents`, or root `AGENTS.md`.
4. Repo-local `.codex\skills` is absent; skills come from `dotnet-harness:*`.
5. Plugin skill validation passes for `dotnet-harness:task-agents`.
6. `git diff --check -- .codex\agents AGENTS.md` has no whitespace errors when the folder is a git repo; skip this check outside git.

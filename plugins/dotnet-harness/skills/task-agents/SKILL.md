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

1. Phase 0 - Workflow Guardrails.
2. Phase 1 - Goal Boundary.
3. Phase 2 - Intake Planning.
4. Phase 3 - Implementation Coordination.
5. Phase 4 - Specialist Analysis.
6. Phase 5 - Bounded Implementation.
7. Phase 6 - Review.
8. Phase 7 - Verification.
9. Phase 8 - Git Operation.

Read `references/phase-contracts.md` for full phase, Socratic, routing, output, and handoff gate contracts.

## Delegation Core

For non-trivial Task Agents work, the default is actual subagent and safe parallel-agent execution, even when the user does not mention agents. Use direct main-thread work only when the user explicitly opts out of agents with wording such as `에이전트 쓰지마`, `no agents`, `메인에서 직접 해줘`, or `직접 해줘`, the task is trivial, or subagent tooling is unavailable.

Read `references/delegation-policy.md` before spawning or skipping subagents, reporting delegation evidence, using compressed handoffs, or applying the subagent utilization floor.

## Worker Core

Phase 5 workers are `standard`/`deep` only. Do not call `backend-worker`, `frontend-worker`, `test-worker`, or `docs-harness-worker` in `lightweight`.

Read `references/worker-policy.md` before assigning feature slices, deciding `Parallel: yes` or `Parallel: no`, or writing worker handoffs.

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

If the script is unavailable, verify manually:

1. `.codex/agents` contains expected workflow agents.
2. Agent files expose `name`, `description`, `developer_instructions`, `model_reasoning_effort`, `sandbox_mode`.
3. No repo identity hardcoding remains in `.codex/agents`, `task-agents`, or root `AGENTS.md`.
4. Repo-local `.codex\skills` is absent; skills come from `dotnet-harness:*`.
5. Plugin skill validation passes for `dotnet-harness:task-agents`.
6. `git diff --check -- .codex\agents AGENTS.md` has no whitespace errors when the folder is a git repo; skip this check outside git.

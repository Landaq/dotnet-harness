---
name: task-agents
description: Route project work through discovered repo-local task agents and skills in workflow order. Use when a request needs staged specialist handling, such as architecture planning, backend service boundaries, frontend UI policy, TDD sequencing, reference audits, or any multi-step implementation/review workflow. This skill is project-local but must discover project names, solution files, agents, and skills from the current repository instead of hardcoding them.
---

# Task Agents

Use to coordinate repo-local specialist agents without hardcoding project names, solution names, or fixed paths beyond standard discovery locations.

## Discovery First

Before routing, inspect current repo:

1. List `.codex/agents/*.toml`; read each `name`, `description`, `developer_instructions` summary.
2. List `.codex/skills/*/SKILL.md`; read frontmatter `name` + `description`.
3. Detect solution anchors from `*.slnx`, `*.sln`, `src/`, `test/`, and `docs/`.
4. Treat missing agents/skills as routing constraints, not fatal errors. Report missing capability; continue closest available workflow.

Do not hardcode repo identity strings. Refer to discovered solution, folders, agents, skill names.

## Routing Order

Run stages in order unless user narrows task:

1. **Workflow gate**
   - Use discovered workflow/guardrails agent or skill first.
   - Classify the request as complex, backend, frontend, audit, or test-only work.
   - State assumptions, ambiguity, approval boundaries, affected paths, success criteria.
   - If ambiguity > discovered guardrail threshold, ask max three Korean clarification questions; pause impl.

2. **Domain specialist**
   - Backend service structure/boundary work: route to discovered service-template agent/skill.
   - Frontend/UI component work: route to discovered frontend-ui agent/skill.
   - Architecture/process comparison: route to discovered reference-auditor agent/skill.
   - If multiple specialists apply, run sequential dependency order: backend boundary before API/UI, contract before UI consumption, audit before remediation.

3. **TDD/test gate**
   - Use discovered TDD/test agent or skill before behavior-changing impl.
   - Define Red-Green-Refactor sequence + exact test folder responsibility.
   - For structure-only tasks, state why tests not required or name architecture check covering change.

4. **Implementation handoff**
   - Implement only after scope, specialist constraints, test strategy clear.
   - Keep edits surgical + tied to user request.
   - Do not create branches, worktrees, commits, pushes, merges, resets, cleans, database changes, or destructive actions without explicit user approval.

5. **Review and audit**
   - After impl, run relevant specialist review again.
   - For broad/architecture changes, run reference-auditor stage before completion.
   - If reviewing, report findings first, then changes + residual risk.

6. **Verification**
   - Run smallest command proving claim: build, test, lint, file inspection, or targeted command.
   - Report actual command outcomes. Do not claim completion from intent.

## Agent Selection Rules

Match agents by discovered `name` + `description`, not filename. Prefer capabilities when present:

- workflow or guardrails: request classification, ambiguity reduction, approvals.
- service or backend template: service folders, DDD/Clean Architecture layers, contracts.
- frontend or UI policy: Blazor UI, component library choice, render mode, Web.Client safety.
- TDD or test: Red-Green-Refactor, test placement, validation scope.
- reference or audit: architecture/process comparison and prioritized remediation.

If capability has no matching agent but matching skill exists, use skill directly. If neither exists, continue with general engineering judgment; call out gap.

## Output Contract

For orchestration turns, include:

- `Stage`: current workflow stage.
- `Discovered`: relevant agents/skills found.
- `Route`: next specialist or skill to use.
- `Gate`: clarification, approval, test, or verification requirement.
- `Action`: what happens next.

Keep Korean-first clarification concise; preserve English technical keywords.

## Stop Conditions

Pause + ask user when:

- service boundary, target project, render mode, or acceptance criteria unclear;
- destructive or git-publishing action needed;
- secrets, credentials, or production access needed;
- no discovered agent/skill safely covers high-risk stage.

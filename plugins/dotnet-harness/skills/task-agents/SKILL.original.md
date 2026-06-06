---
name: task-agents
description: Route project work through discovered repo-local task agents and skills in workflow order. Use when a request needs staged specialist handling, such as architecture planning, backend service boundaries, frontend UI policy, TDD sequencing, reference audits, or any multi-step implementation/review workflow. This skill is project-local but must discover project names, solution files, agents, and skills from the current repository instead of hardcoding them.
---

# Task Agents

Use this skill to coordinate repo-local specialist agents without baking in project names, solution names, or fixed file paths beyond standard discovery locations.

## Discovery First

Before routing work, inspect the current repository:

1. List `.codex/agents/*.toml` and read each `name`, `description`, and `developer_instructions` summary.
2. List `.codex/skills/*/SKILL.md` and read frontmatter `name` and `description`.
3. Detect solution anchors from `*.slnx`, `*.sln`, `src/`, `test/`, and `docs/`.
4. Treat missing agents or skills as routing constraints, not fatal errors. Report the missing capability and continue with the closest available workflow.

Do not hardcode repository identity strings. Refer to the discovered solution, folders, agents, and skill names.

## Routing Order

Run stages in this order unless the user explicitly narrows the task:

1. **Workflow gate**
   - Use the discovered workflow/guardrails agent or skill first.
   - Classify the request as complex, backend, frontend, audit, or test-only work.
   - State assumptions, ambiguity, approval boundaries, affected paths, and success criteria.
   - If ambiguity is above the discovered guardrail threshold, ask at most three Korean clarification questions and pause implementation.

2. **Domain specialist**
   - Backend service structure or service-boundary work: route to the discovered service-template agent/skill.
   - Frontend or UI component work: route to the discovered frontend-ui agent/skill.
   - Architecture/process comparison: route to the discovered reference-auditor agent/skill.
   - If more than one specialist applies, run them sequentially in dependency order: backend boundary before API/UI, contract before UI consumption, audit before remediation.

3. **TDD/test gate**
   - Use the discovered TDD/test agent or skill before implementation that changes behavior.
   - Define Red-Green-Refactor sequence and exact test folder responsibility.
   - For structure-only tasks, state why tests are not required or name the architecture check that covers the change.

4. **Implementation handoff**
   - Implement only after scope, specialist constraints, and test strategy are clear.
   - Keep edits surgical and tied to the user request.
   - Do not create branches, worktrees, commits, pushes, merges, resets, cleans, database changes, or destructive actions without explicit user approval.

5. **Review and audit**
   - After implementation, run the relevant specialist review again.
   - For broad or architectural changes, run the reference-auditor stage before completion.
   - Report findings first if reviewing, then summarize changes and residual risk.

6. **Verification**
   - Run the smallest command that proves the claim: build, test, lint, file inspection, or targeted command.
   - Report actual command outcomes. Do not claim completion from intent.

## Agent Selection Rules

Match agents by discovered `name` and `description`, not filename. Prefer these capabilities when present:

- workflow or guardrails: request classification, ambiguity reduction, approvals.
- service or backend template: service folders, DDD/Clean Architecture layers, contracts.
- frontend or UI policy: Blazor UI, component library choice, render mode, Web.Client safety.
- TDD or test: Red-Green-Refactor, test placement, validation scope.
- reference or audit: architecture/process comparison and prioritized remediation.

If a capability has no matching agent but has a matching skill, use the skill directly. If neither exists, continue with general engineering judgment and call out the gap.

## Output Contract

For orchestration turns, include:

- `Stage`: current workflow stage.
- `Discovered`: relevant agents/skills found.
- `Route`: next specialist or skill to use.
- `Gate`: clarification, approval, test, or verification requirement.
- `Action`: what happens next.

Keep Korean-first user-facing clarification concise, while preserving English technical keywords.

## Stop Conditions

Pause and ask the user when:

- the service boundary, target project, render mode, or acceptance criteria are unclear;
- destructive or git-publishing actions are needed;
- required secrets, credentials, or production access would be needed;
- no discovered agent/skill can safely cover a high-risk stage.

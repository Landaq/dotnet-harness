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

## Documentation Grounding

Use Context7 MCP when implementation, review, audit, or verification depends on current external library/framework/API documentation. Prefer it before making claims about package APIs, setup, configuration, or version-specific behavior.

## Routing Order

Run stages in order unless user narrows task:

1. **Safety gate**
   - Use discovered workflow/guardrails agent or skill first.
   - Identify destructive actions, git publishing, branch/worktree changes, merges, resets, cleans, database changes, secret handling, production access, and unclear approval boundaries.
   - Classify the request as complex, backend, frontend, audit, test-only, verification-only, or git-operation work.
   - Use discovered guardrail thresholds when present: complex work 13%, backend work 5%, frontend work 5%.
   - If ambiguity exceeds the matching threshold, ask max three Korean clarification questions; pause implementation.
   - If no threshold is discoverable, state the ambiguity and ask max three Korean clarification questions before implementation.

2. **Intake planning**
   - Use discovered intake/planner agent when present.
   - Convert the request into work units, affected paths, success criteria, expected outputs, and validation candidates.
   - Keep safety approvals owned by the workflow/guardrails stage.

3. **Implementation coordination**
   - Use discovered implementation/coordinator agent when present.
   - Select applicable domain, test, audit, review, verification, and git agents by discovered `name` + `description`.
   - Decide whether read-only parallel specialist analysis is useful.
   - Merge specialist outputs into one serial implementation order.

4. **Read-only parallel specialist analysis**
   - Backend work can analyze with service-template + TDD/test in parallel.
   - UI/API work can analyze with frontend/UI + service-template + TDD/test in parallel.
   - Structure/governance work can analyze with reference/audit + TDD/test in parallel.
   - Parallel analysis must produce constraints, risks, test requirements, and recommended order; it must not edit files.

5. **Serial implementation**
   - Implement only after safety constraints, work units, specialist constraints, and test strategy are clear.
   - Backend service structure/boundary work routes through discovered service-template agent/skill.
   - Frontend/UI component work routes through discovered frontend-ui agent/skill.
   - Behavior-changing work routes through discovered TDD/test agent/skill before implementation.
   - Keep edits surgical and tied to the user request.

6. **Post-implementation review**
   - Use discovered code-reviewer when present.
   - Run relevant specialist review again for touched domains.
   - For broad/architecture changes, run reference-auditor before completion.
   - Findings come first, followed by residual risk and test gaps.

7. **Verification**
   - Use discovered verification-runner when present.
   - Run the smallest command proving the claim: build, test, lint, file inspection, metadata check, or targeted search.
   - Report actual command outcomes. Do not claim completion from intent.

8. **Explicit git operation**
   - Use discovered git-operator only when the user explicitly asks for commit, push, PR, branch, merge, reset, clean, or worktree actions.
   - Inspect dirty tree, stage narrowly, and leave unrelated changes unstaged.

## Agent Selection Rules

Match agents by discovered `name` + `description`, not filename. Prefer capabilities when present:

- workflow or guardrails: safety, approvals, ambiguity, destructive-action gates.
- intake or planner: work units, affected paths, success criteria, expected outputs.
- implementation or coordinator: specialist selection, parallel analysis decision, serial implementation order.
- service or backend template: service folders, DDD/Clean Architecture layers, contracts.
- frontend or UI policy: Blazor UI, component library choice, render mode, Web.Client safety.
- TDD or test: Red-Green-Refactor, test placement, validation scope.
- reference or audit: architecture/process comparison and prioritized remediation.
- code reviewer or review: diff risks, regressions, scope creep, missing tests, boundary violations.
- verification or runner: command selection, actual result interpretation, completion evidence.
- git operator: explicit user-approved staging, commit, push, and PR preparation.

If capability has no matching agent but matching skill exists, use skill directly. If neither exists, continue with general engineering judgment; call out gap.

## Parallelization Rules

Use parallel work only when outputs are independent and read-only, or when post-implementation reviewers inspect the same completed diff without editing it.

Safe parallel groups:

- Pre-implementation backend analysis: service-template + TDD/test.
- Pre-implementation UI/API analysis: frontend/UI + service-template + TDD/test.
- Pre-implementation structure analysis: reference/audit + TDD/test.
- Post-implementation review: code-reviewer + reference/auditor when architecture boundaries changed.
- Post-implementation verification: verification-runner can run in parallel only when its command is non-mutating and independent of review outputs.

Unsafe parallel work:

- Multiple agents editing the same files.
- git-operator running before implementation, review, and verification finish.
- Implementation before workflow/guardrails clears approval constraints.
- Multiple remediation attempts before a test failure cause is identified.

## Output Contract

For orchestration turns, include:

- `Stage`: current workflow stage.
- `Discovered`: relevant agents/skills found.
- `Route`: ordered stages, including any safe parallel read-only groups.
- `Gate`: clarification, approval, test, verification, or git requirement.
- `Action`: what happens next.

Keep Korean-first clarification concise; preserve English technical keywords.

## Stop Conditions

Pause + ask user when:

- service boundary, target project, render mode, or acceptance criteria unclear;
- destructive, database, secret, production, branch/worktree, merge, reset, clean, or git-publishing action needed;
- multiple agents would need to edit the same files in parallel;
- no discovered agent/skill safely covers high-risk stage.

## Dry-Run Validation

After changing agents or this skill, run:

```powershell
pwsh -NoProfile -File .codex/scripts/validate-task-agents.ps1
```

If the script is unavailable, verify manually:

1. `.codex/agents` contains expected workflow agents.
2. Agent files expose `name`, `description`, `developer_instructions`, `model_reasoning_effort`, `sandbox_mode`.
3. No repo identity hardcoding remains in `.codex/agents`, `task-agents`, or root `AGENTS.md`.
4. `quick_validate.py .codex\skills\task-agents` passes.
5. `git diff --check -- .codex\agents .codex\skills\task-agents AGENTS.md` has no whitespace errors.

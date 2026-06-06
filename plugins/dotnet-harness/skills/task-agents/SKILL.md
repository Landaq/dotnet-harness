---
name: task-agents
description: Route project work through discovered repo-local task agents and dotnet-harness plugin skills in workflow order. Use when a request needs staged specialist handling, such as architecture planning, backend service boundaries, frontend UI policy, TDD sequencing, reference audits, or any multi-step implementation/review workflow. This skill must discover project names, solution files, agents, and plugin skills instead of hardcoding them.
---

# Task Agents

Use to coordinate repo-local specialist agents without hardcoding project names, solution names, or fixed paths beyond standard discovery locations.

## Discovery First

Before routing, inspect current repo:

1. List `.codex/agents/*.toml`; read each `name`, `description`, `developer_instructions` summary.
2. Use `dotnet-harness:*` plugin skills as the skill source. Do not require or create repo-local `.codex/skills`.
3. Detect project structure anchors from `src/`, `test/`, and `docs/Project/README.md`; also detect solution anchors from `*.slnx` and `*.sln`.
4. Treat missing agents/skills as routing constraints, not fatal errors. Report missing capability; continue closest available workflow.

Do not hardcode repo identity strings. Refer to discovered solution, folders, agents, skill names.

## Agent Execution Contract

Task Agents must use actual subagents when subagent tooling is available and the task is non-trivial.

- Treat `.codex/agents/*.toml` as executable role contracts, not just reference documents.
- For each selected role, pass the discovered agent `name`, `description`, and relevant `developer_instructions` summary into the delegated subagent task.
- Use `dotnet-harness:*` plugin skills as the skill contract inside the delegated prompt.
- Keep the main thread responsible for scope, approvals, final integration, file ownership, and final answer.
- Use subagents for read-only analysis, bounded implementation with disjoint write sets, post-implementation review, and verification.
- Do not spawn subagents for trivial one-file edits, direct user questions, or work whose next step is fully blocked on one local decision.
- If subagent tooling is unavailable, explicitly report `Agent execution fallback: unavailable` and continue with the same staged role order in the main thread.

Delegated prompts must include:

1. selected role name;
2. active goal and non-goals;
3. allowed paths and forbidden paths;
4. expected output or changed file list;
5. validation command or evidence requirement;
6. instruction to avoid git operations unless the role is `git-operator` and the user explicitly requested git work.

## Project Structure Gate

Before task routing, confirm the baseline project structure exists:

- `src/`
- `test/`
- `docs/Project/README.md`

If any baseline anchor is missing, warn the user that the project baseline is not ready. Route first to `project-structure-setup` and instruct the user to run project setup before Task Agents continue. Do not proceed to implementation routing until the structure gate is satisfied or the user explicitly narrows the task to agent/skill maintenance.

## Documentation Grounding

Use Context7 MCP only when implementation, review, audit, or verification depends on current external library/framework/API documentation.

Before querying:

1. Inspect local files first to discover package names, target framework, versions, and affected APIs.
2. Name the exact library/framework and one focused question the docs must answer.
3. Query the smallest relevant topic; avoid broad best-practice searches.
4. Tie the documentation result back to a local decision, file, command, or risk.

Do not use Context7 for repo-local routing, approval gates, generic architecture opinions, style preferences, or decisions already defined by local skills/agents.

## Routing Order

Run stages in order unless user narrows task:

1. **Safety gate**
   - Use discovered workflow/guardrails agent or skill first.
   - Confirm the project structure gate is satisfied before implementation routing.
   - Identify destructive actions, git publishing, branch/worktree changes, merges, resets, cleans, database changes, secret handling, production access, and unclear approval boundaries.
   - Classify the request as complex, backend, frontend, audit, test-only, verification-only, or git-operation work.
   - Use discovered guardrail thresholds when present: complex work 13%, backend work 5%, frontend work 5%.
   - If ambiguity exceeds the matching threshold, ask max three Korean clarification questions; pause implementation.
   - If no threshold is discoverable, state the ambiguity and ask max three Korean clarification questions before implementation.

2. **Goal boundary**
   - Use discovered goal-boundary agent when present.
   - Split broad requests into feature-sized goals when each feature has independent success criteria and validation.
   - Define one explicit goal statement per active feature before planning.
   - Estimate ambiguity percentage for each active feature goal.
   - Continue Socratic clarification until the average ambiguity across active feature goals is 8% or lower.
   - If the request is too broad or the active goals cannot reach the 8% average ambiguity gate, narrow the active target to one feature goal and move the rest to Out Of Scope or Todo.
   - Separate In Scope, Out Of Scope, Assumptions, Success Criteria, Deliverables, and Stop Conditions.
   - Detect mixed objectives, such as plugin behavior vs current repo policy, setup vs upgrade, implementation vs git publishing, or docs vs runtime behavior.
   - If goal boundary is unclear, run a short Socratic clarification interview before planning:
     - State the current best assumption first.
     - Ask max three Korean questions.
     - Each question must expose a priority, tradeoff, non-goal, validation standard, output location, git/release expectation, or stop condition.
     - Prefer contrastive questions that let the user choose what to include and what to exclude.
     - Continue in follow-up turns until active feature goals average 8% ambiguity or lower.
   - Pause planning until the user answer makes the boundary actionable.

3. **Intake planning**
   - Use discovered intake/planner agent when present.
   - Convert the request into work units, affected paths, success criteria, expected outputs, and validation candidates.
   - Keep safety approvals owned by the workflow/guardrails stage.

4. **Implementation coordination**
   - Use discovered implementation/coordinator agent when present.
   - Select applicable domain, test, audit, review, verification, and git agents by discovered `name` + `description`.
   - Decide whether read-only parallel specialist analysis is useful for each feature goal.
   - Allow multiple feature goals to proceed together only when each has independent success criteria, independent validation, and no shared write conflicts.
   - Merge specialist outputs into one serial implementation order.

5. **Subagent delegation**
   - Spawn selected specialist subagents when the Agent Execution Contract allows it.
   - Prefer parallel read-only analysis groups before implementation when specialists can inspect independently.
   - Prefer delegated bounded implementation only when write sets are disjoint and the task can be described without unresolved decisions.
   - Keep the immediate blocking task in the main thread when waiting would slow the critical path.
   - After each subagent returns, review its output before using it as implementation or verification evidence.

6. **Read-only parallel specialist analysis**
   - Backend work can analyze with service-template + TDD/test in parallel.
   - UI/API work can analyze with frontend/UI + service-template + TDD/test in parallel.
   - Structure/governance work can analyze with reference/audit + TDD/test in parallel.
   - Parallel analysis must produce constraints, risks, test requirements, and recommended order; it must not edit files.

7. **Serial implementation**
   - Implement only after safety constraints, work units, specialist constraints, and test strategy are clear.
   - Backend service structure/boundary work routes through discovered service-template agent/skill.
   - Frontend/UI component work routes through discovered frontend-ui agent/skill.
   - Behavior-changing work routes through discovered TDD/test agent/skill before implementation.
   - Keep edits surgical and tied to the user request.

8. **Post-implementation review**
   - Use discovered code-reviewer when present.
   - Spawn code-reviewer as a subagent when subagent tooling is available and a meaningful diff exists.
   - Run relevant specialist review again for touched domains.
   - For broad/architecture changes, run reference-auditor before completion.
   - Findings come first, followed by residual risk and test gaps.

9. **Verification**
   - Use discovered verification-runner when present.
   - Spawn verification-runner as a subagent only when it can inspect or run commands independently of ongoing edits.
   - Run the smallest command proving the claim: build, test, lint, file inspection, metadata check, or targeted search.
   - Report actual command outcomes. Do not claim completion from intent.
   - Write a Task Result HTML artifact only when the user explicitly requests a result report.

10. **Explicit git operation**
   - Use discovered git-operator only when the user explicitly asks for commit, push, PR, branch, merge, reset, clean, or worktree actions.
   - Inspect dirty tree, stage narrowly, and leave unrelated changes unstaged.

## Agent Selection Rules

Match agents by discovered `name` + `description`, not filename. Prefer capabilities when present:

- workflow or guardrails: safety, approvals, ambiguity, destructive-action gates.
- goal or boundary: explicit goal, non-goals, scope limits, deliverables, success criteria, stop conditions.
- intake or planner: work units, affected paths, success criteria, expected outputs.
- implementation or coordinator: specialist selection, parallel analysis decision, serial implementation order.
- service or backend template: service folders, DDD/Clean Architecture layers, contracts.
- frontend or UI policy: Blazor UI, component library choice, render mode, Web.Client safety.
- TDD or test: Red-Green-Refactor, test placement, validation scope.
- reference or audit: architecture/process comparison and prioritized remediation.
- code reviewer or review: diff risks, regressions, scope creep, missing tests, boundary violations.
- verification or runner: command selection, actual result interpretation, completion evidence.
- git operator: explicit user-approved staging, commit, push, and PR preparation.

If capability has no matching agent but matching `dotnet-harness:*` plugin skill exists, use the plugin skill directly. If neither exists, continue with general engineering judgment; call out gap.

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
- `Delegation`: spawned subagents, skipped subagents with reasons, or fallback status.
- `Gate`: clarification, approval, test, verification, or git requirement.
- `Action`: what happens next.

Keep Korean-first clarification concise; preserve English technical keywords.

## Optional Task Result Artifact

Create a visible HTML result file only when the user explicitly asks for a Task Result report or a result artifact:

- Directory: `docs/TaskResult` (create if missing).
- Filename: `{yyMMdd}_{summary}_Result.html`.
- `summary`: short lowercase kebab-case summary from the request/result; keep filesystem-safe.
- If the same filename exists, append `-2`, `-3`, etc. before `_Result.html`.
- Keep only the newest 10 `*_Result.html` files; delete the oldest extras.
- Sections must be:
  1. `요청사항`
  2. `작업내용`
  3. `작업결과`
  4. `Todo`

Prefer the helper script when available:

```powershell
pwsh -NoProfile -File .codex\scripts\write-task-result.ps1 -Summary "short-summary" -Request "..." -Work "..." -Result "..." -Todo "..."
```

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
4. Repo-local `.codex\skills` is absent; skills come from `dotnet-harness:*`.
5. Plugin skill validation passes for `dotnet-harness:task-agents`.
6. `git diff --check -- .codex\agents AGENTS.md` has no whitespace errors when the folder is a git repo; skip this check outside git.

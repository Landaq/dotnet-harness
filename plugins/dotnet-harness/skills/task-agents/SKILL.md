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

## Agent-First Orchestration

Main thread is the orchestrator, not the default implementer, for non-trivial work when task-agents is active.

Agent-first handoff is the default for non-trivial dotnet-harness work. The user does not need to explicitly request subagent handoff.

Agent-first means planning, implementation, review, and verification should be delegated to discovered repo-local agents whenever the task is non-trivial and subagent capability is available.

When task-agents is active, the main thread is a coordinator/reporter, not the default implementer.

Subagents own staged analysis, implementation, review, and verification. Main thread edits are exceptions and must be reported.

Each subagent output must be treated as the input contract for the next stage.

Run task-agent routing before non-trivial implementation starts. If the user explicitly says `/feedback`, `task-agents`, `에이전트를 활용`, `에이전트들이 전반적으로 수행`, `agents overall`, `run agents`, or similar wording, treat the request as agent-first orchestration instead of agent-assisted review.

Direct main-thread edits are allowed only for small fixes, integration of agent output, or non-overlapping unblock work. Non-overlapping verification or cleanup is allowed when it does not duplicate a running subagent's scope. When a delegated subagent is running, the main thread must not implement overlapping work; it may only perform non-overlapping verification, documentation lookup, diff inspection, or integration planning.

Automatic agent-first trigger:

- If the user explicitly invokes `@dotnet-harness` for non-trivial work, treat the request as task-agents active and agent-first unless the user explicitly opts out of agents.
- Treat the request as agent-first when the newest user message mentions `@dotnet-harness`, `$dotnet-harness`, `dotnet-harness`, `task-agents`, `/feedback`, `에이전트`, `agents overall`, `run agents`, or asks for non-trivial work.
- Non-trivial work means multi-step, multi-file, architecture/workflow/plugin/harness change, backend/frontend behavior change, test strategy, review, verification, CI, release-sensitive, or unclear approval-boundary work.
- Direct-main opt-out applies only when the newest user message explicitly says: `direct main`, `main thread only`, `no agents`, `skip agents`, `don't delegate`, `no subagents`, `직접 처리`, `메인에서만`, `에이전트 쓰지마`, `에이전트 사용하지 마`, or `위임하지 마`.
- If agent-first trigger and direct-main opt-out both appear, the newest explicit instruction wins for delegation only. Safety, goal boundary, validation, TaskResult, and git gates still apply.
- If the user says `에이전트 쓰지마`, `no agents`, or equivalent explicit opt-out, do not spawn subagents; report `Delegation: skipped user-opt-out` and continue main-thread direct.

Main-thread direct work is allowed for a direct answer, status check, trivial one-file fix, or explicit agent opt-out.

Default stage ownership:

- intake/planning: discovered intake/planner agent defines work units, success criteria, affected paths, expected outputs, and validation candidates.
- implementation: discovered implementation/coordinator assigns bounded implementation to the best matching specialist or implementation subagent when write scope is settled.
- feedback/code-review: discovered feedback or code-review agent identifies risks, regressions, scope creep, missing tests, and boundary violations; when useful, attach it early as a parallel reviewer instead of waiting only until implementation is complete.
- verification: discovered verification-runner selects and runs or specifies the smallest proof.
- git operator: discovered git-operator acts only when the user explicitly asks for commit, push, PR, branch, merge, reset, clean, or worktree actions.

If no agent is called, report why briefly with `Delegation: skipped <reason>`.

Strict staged handoff order:

1. `workflow-guardrails`
2. `goal-boundary`
3. `intake-planner`
4. `implementation-coordinator`
5. pre-implementation read-only specialists
6. bounded implementation
7. `code-reviewer`
8. `verification-runner`
9. `git-operator` only when the user explicitly requested git work

Each stage consumes the prior stage output as input. No later stage may widen scope, loosen non-goals, or change validation without returning to `goal-boundary`.

## Mandatory Socratic Checkpoint

For non-trivial Task Agents work, run a Socratic clarification checkpoint before intake planning, subagent delegation, implementation, or verification.

Ask at least one Korean Socratic question unless one of these skip conditions is true:

- The task is a direct answer, status check, or trivial one-file mechanical edit.
- The user already provided all of: explicit goal, in-scope work, out-of-scope work or non-goal, success criteria, validation command/evidence, and git/release expectation.
- The newest user message explicitly says not to ask questions, or explicitly approves proceeding with the current assumptions.

When asking:

1. State the current best assumption first.
2. State current ambiguity percentage and target average ambiguity `<= 8%`.
3. Ask 1-3 Korean questions that expose priority, tradeoff, non-goal, affected surface, output location, validation standard, git/release expectation, or stop condition.
4. Prefer contrastive questions that let the user include one thing and exclude another.
5. Stop all planning and implementation until the user answers.

When the user answers a Socratic question:

1. Interpret the answer into updated Goal, In Scope, Out Of Scope, Success Criteria, Deliverables, Stop Conditions, and Todo.
2. Recalculate ambiguity percentage for each active feature goal and the average ambiguity after every answer.
3. Check goal alignment after every answer: the clarified answer must support the active goal, scope boundary, validation standard, and stop condition.
4. If average ambiguity remains above `8%`, or the clarified answer does not align with the active goal, ask another 1-3 Korean Socratic questions and pause again.
5. Continue this answer -> reassess -> ask loop until average ambiguity is `<= 8%` and the active goal is aligned enough to plan.
6. If repeated answers keep broadening scope, narrow to one active feature goal and move the rest to Out Of Scope or Todo before asking the next question.
7. Before proceeding past the checkpoint, print `Socratic: satisfied` with the final average ambiguity, aligned goal, remaining assumptions, and next stage.

When skipping:

- Print `Socratic: skipped` with the exact skip condition.
- List the assumed goal, scope, success criteria, validation, and git/release expectation.
- Continue only if the assumptions are actionable.

## Agent Execution Contract

Task Agents must use actual subagents when subagent tooling is available and the task is non-trivial.

- Actual subagent execution means calling an available delegated-agent tool such as `spawn_agent` or the environment's equivalent subagent runner.
- Treat `.codex/agents/*.toml` as executable role contracts, not just reference documents.
- Reading agent TOML, summarizing an agent persona, or role-playing a specialist in the main thread does not count as subagent execution.
- For each selected role, pass the discovered agent `name`, `description`, and relevant `developer_instructions` summary into the delegated subagent task.
- Use `dotnet-harness:*` plugin skills as the skill contract inside the delegated prompt.
- Keep the main thread responsible for scope, approvals, final integration, file ownership, and final answer.
- Use subagents for read-only analysis, bounded implementation with disjoint write sets, post-implementation review, and verification.
- Do not spawn subagents for trivial one-file edits, direct user questions, or work whose next step is fully blocked on one local decision.
- Before fallback, inspect active callable tools. If any delegated-agent runner is callable, including `spawn_agent`, `delegate_task`, `run_agent`, or the environment equivalent, call it.
- Do not report `Agent execution fallback: unavailable` while such a tool is callable.
- If subagent tooling is unavailable after checking callable tools, explicitly report `Agent execution fallback: unavailable` and continue with the same staged role order in the main thread.
- Fallback requires `Tool availability checked:` with callable delegated-agent tool names or `none`, plus the exact tool error if a delegated call was attempted.
- Keeping an immediate blocking task in the main thread does not remove the requirement to spawn at least one independent read-only specialist for complex or multi-step work when one exists.
- For non-trivial work, proceeding with main-thread-only execution while subagent tooling is available is noncompliant unless the decision is reported as `Delegation: skipped` with `trivial`, `blocked`, `coupled`, or `unsafe`.

Delegated prompts must include:

1. selected role name;
2. active goal and non-goals;
3. allowed paths and forbidden paths;
4. expected output or changed file list;
5. validation command or evidence requirement;
6. instruction to avoid git operations unless the role is `git-operator` and the user explicitly requested git work.

## Delegation Evidence

When subagent tooling is available and used, Task Agents output must include `Delegation: used` before or during implementation:

```text
Delegation: used
Callable Namespace:
Tool:
Tool availability checked:
Tool Call Receipt:
Tool Result Status:
Agent:
Role:
Purpose:
Status:
Result Used:
```

If the environment has no usable subagent tool, output both:

```text
Agent execution fallback: unavailable
Tool availability checked:
Delegation: skipped unavailable
```

`Delegation: used` is valid only when backed by an actual tool-call receipt visible in the transcript. Do not synthesize this block from a delegation plan.

Do not mark utilization satisfied from planned delegation, simulated agent reasoning, or reading `.codex/agents/*.toml`. Utilization is satisfied only by an actual subagent tool call with receipt evidence, or by an explicit fallback/skip record with the concrete reason.

## Compressed Agent Handoff

Use `caveman full` only for internal subagent handoff prompts and subagent return summaries. This reduces orchestration token cost while keeping the main thread responsible for clear user-facing communication.

Do not use `caveman full` for user-facing Socratic questions, approval requests, destructive-risk warnings, release/git confirmations, or final user responses.

Compressed handoffs must preserve exact file paths, commands, errors, API names, package names, versions, agent names, skill names, and line references.

Internal handoff prompt format:

```text
Mode: caveman full
Role:
Goal:
Non-goals:
Allow:
Deny:
Need:
Verify:
No git unless explicit.
Return:
Findings:
Changes:
Risks:
Verify:
Next:
```

Internal subagent return format:

```text
Findings:
Changes:
Risks:
Verify:
Next:
```

Subagent output as next input:

- Main thread must treat `Findings`, `Changes`, `Risks`, `Verify`, and `Next` as the next stage input, not as final truth.
- Every later subagent prompt must include relevant prior `Findings`, accepted constraints, unresolved `Risks`, required `Verify`, and `Next`.
- If prior outputs conflict, lack evidence, or exceed scope, main thread resolves the conflict or sends a bounded follow-up before implementation or completion.

Keep compressed agent messages free of greetings, repeated background, broad explanations, and implementation trivia that does not affect the next decision. Expand or clarify the result in the main thread before showing it to the user.

## Subagent Utilization Floor

For non-trivial Task Agents work, the default is delegation, not local-only execution.

When subagent tooling is available:

- For complex or multi-step work, spawn at least one read-only specialist subagent before implementation unless fallback or an explicit skip condition applies.
- Spawn at least one pre-implementation specialist subagent before editing files, unless the task is a direct answer, status check, trivial one-file mechanical edit, or fully blocked on a user decision.
- For implementation tasks that create a meaningful diff, spawn at least one post-implementation subagent: `code-reviewer`, `verification-runner`, or `reference-auditor`.
- For architecture, workflow, plugin, harness, or multi-file changes, prefer two independent read-only specialist subagents when their questions do not overlap.
- For backend behavior changes, prefer `service-template` and `tdd-test` as parallel read-only specialists before implementation.
- For backend non-trivial work, spawn `service-template` and `tdd-test` as read-only specialists before implementation unless fallback, explicit opt-out, or a concrete skip condition applies.
- For frontend behavior changes, prefer `frontend-ui` and `tdd-test` as parallel read-only specialists before implementation.
- For plugin/harness governance changes, prefer `reference-auditor` and `code-reviewer` as independent review specialists.
- Do not count reading an agent TOML file as subagent usage. Only an actual delegated subagent task counts.
- Do not count main-thread role-play as subagent usage. A selected role must have a tool-call receipt or an explicit skip/fallback reason.

If an eligible role is not spawned, output `Delegation: skipped` with the concrete reason:

- `trivial`: direct answer, status check, or trivial one-file mechanical edit.
- `blocked`: Socratic checkpoint, approval, or missing target information blocks delegation.
- `coupled`: no disjoint read-only question or write set exists.
- `unavailable`: subagent tooling is unavailable.
- `unsafe`: delegation would touch secrets, production state, destructive actions, or git operations without explicit approval.

No-spawn decisions must include the exact reason.

Default spawn caps:

- Limit pre-implementation read-only subagents to three unless the user explicitly approves more.
- Delegate implementation only when write sets are disjoint and requirements are settled.
- Limit delegated implementation subagents to one unless the user explicitly approves multiple isolated write scopes.
- Limit post-implementation review and verification subagents to two unless the changed surface spans independent domains.

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
   - Run the Mandatory Socratic Checkpoint before planning unless a skip condition applies.
   - Split broad requests into feature-sized goals when each feature has independent success criteria and validation.
   - Define one explicit goal statement per active feature before planning.
   - Estimate ambiguity percentage for each active feature goal.
   - After every user answer, restate the updated goal boundary, recalculate each feature ambiguity %, recalculate average ambiguity %, and check whether the answer still aligns with the active goal.
   - Continue Socratic clarification until the average ambiguity across active feature goals is 8% or lower and the active goal is aligned with scope, validation, and stop conditions.
   - If the request is too broad or the active goals cannot reach the 8% average ambiguity gate, narrow the active target to one feature goal and move the rest to Out Of Scope or Todo.
   - Separate In Scope, Out Of Scope, Assumptions, Success Criteria, Deliverables, and Stop Conditions.
   - Detect mixed objectives, such as plugin behavior vs current repo policy, setup vs upgrade, implementation vs git publishing, or docs vs runtime behavior.
   - If goal boundary is unclear, run a short Socratic clarification interview before planning:
     - State the current best assumption first.
     - Ask max three Korean questions.
     - Each question must expose a priority, tradeoff, non-goal, validation standard, output location, git/release expectation, or stop condition.
     - Prefer contrastive questions that let the user choose what to include and what to exclude.
     - After each answer, update the boundary, recalculate ambiguity, check goal alignment, and ask the next question if the average remains above 8% or the answer shifts the target goal.
     - Continue in follow-up turns until active feature goals average 8% ambiguity or lower and the target goal is aligned.
   - Pause planning until the user answer makes the boundary actionable.

3. **Intake planning**
   - Use discovered intake/planner agent when present.
   - Convert the request into work units, affected paths, success criteria, expected outputs, and validation candidates.
   - Keep safety approvals owned by the workflow/guardrails stage.
   - If the user requested `/feedback` or agent-wide execution, mark the route as agent-first orchestration and include feedback/code-review in the initial route.

4. **Implementation coordination**
   - Use discovered implementation/coordinator agent when present.
   - Select applicable domain, test, audit, review, verification, and git agents by discovered `name` + `description`.
   - Decide whether read-only parallel specialist analysis is useful for each feature goal.
   - Allow multiple feature goals to proceed together only when each has independent success criteria, independent validation, and no shared write conflicts.
   - If agent questions, evidence duties, or write sets overlap, merge them, serialize them, or skip the duplicate role with `Delegation: skipped coupled`.
   - Merge specialist outputs into one serial implementation order.

5. **Subagent delegation**
   - Spawn selected specialist subagents when the Agent Execution Contract allows it.
   - Enforce the Subagent Utilization Floor for every non-trivial task.
   - Prefer parallel read-only analysis groups before implementation when specialists can inspect independently.
   - Prefer delegated bounded implementation only when write sets are disjoint and the task can be described without unresolved decisions.
   - Keep the immediate blocking task in the main thread when waiting would slow the critical path.
   - While subagents are running, do not duplicate their implementation scope in the main thread.
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
   - Main-thread implementation is limited to small fixes, integration of agent output, non-overlapping unblock work, or changes that no eligible agent can safely perform.
   - Keep edits surgical and tied to the user request.

8. **Post-implementation review**
   - Use discovered code-reviewer when present.
   - Spawn code-reviewer as a subagent when subagent tooling is available and a meaningful diff exists.
   - If `/feedback` is requested, route to feedback/code-review early and again after meaningful changes when possible.
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
- `Socratic`: questions asked, skipped with reason, or blocked waiting for user answer.
- `Delegation`: spawned subagents, skipped eligible roles with concrete reasons, utilization floor satisfied or not, and fallback status.
- `Gate`: clarification, approval, test, verification, or git requirement.
- `Action`: what happens next.

Keep Korean-first clarification concise; preserve English technical keywords.

Before the final user response, report:

- `Agents Used`: agents called, role, purpose, and whether each result was reflected.
- `Agents Skipped`: skipped eligible agents and short reason, or `none`.
- `Agent Results Reflected`: yes/no; if no, state why.
- `Main Thread Work`: integration, non-overlapping verification, cleanup, or unblock work performed directly.
- `Review/Verification Evidence`: reviewer findings and validation command outcomes.
- `Files Changed`: changed paths.
- `Git`: `not requested; git-operator not used` unless the user explicitly requested commit, push, PR, branch, merge, reset, clean, or worktree work.
- `TaskResult`: `not requested; not created` unless the user explicitly requested it.

## Optional Task Result Artifact

TaskResult remains opt-in only.

TaskResult is opt-in only. Create it only when the user explicitly says `TaskResult`, `result report`, `HTML report`, `결과 HTML`, `작업 결과 파일`, or equivalent artifact request. Do not infer TaskResult from `summarize`, `report back`, `verify`, or normal final-response wording.

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

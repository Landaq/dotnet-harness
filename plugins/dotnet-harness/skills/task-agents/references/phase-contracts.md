# Phase Contracts

## Clarify Before Delegating

Task Agents must clarify before delegating. Actual subagent execution begins only after Socratic goal clarification is satisfied and runtime delegation permission is present.

When task-agents is active, the main thread is a coordinator/reporter, not the default implementer. The main thread owns requirement intake, Socratic clarification, ambiguity recalculation, goal boundary confirmation, agent route planning, result integration, and final reporting.

Subagents own staged analysis, implementation, review, and verification only after clarification passes and delegation permission is present. Each subagent output must be treated as the input contract for the next stage.

Do not implement or spawn worker subagents immediately after the user request. First clarify the goal. Then recalculate ambiguity. Then confirm the boundary. Then plan the route. Then hand off if allowed.

Direct main-thread edits are allowed for direct answers, trivial one-file fixes, user opt-out, host-policy no-spawn fallback, integration of accepted agent output, or non-overlapping unblock work. Direct work must be reported.

Main-thread direct work is allowed for a direct answer, status check, trivial one-file fix, explicit agent opt-out, or proven subagent tooling fallback.

If no agent is called, report why briefly with `Delegation: skipped <reason>`.

## Delegation Permission Gate

Treat the following as explicit authorization for actual subagent execution after clarification:

- `$dotnet-harness`
- `task-agents`
- `/feedback`
- `에이전트`
- `subagent`
- `서브에이전트`
- `에이전트에게 맡겨`
- `작업을 에이전트들이 수행`

If the user asks for implementation, refactoring, review, validation, frontend, backend, full-stack, plugin, or harness work without agent wording, check runtime policy:

- If runtime policy allows default subagent execution, proceed to route planning after Socratic clarification.
- If runtime policy requires explicit authorization, do not spawn actual subagents. Ask briefly `에이전트에게 맡겨 진행할까요?`, or report `Delegation: skipped no-explicit-agent-request` and continue main-thread direct after clarification.
- If the user says `에이전트 쓰지마`, `no agents`, `skip agents`, `직접 해줘`, `메인에서 직접 해줘`, `빠르게 메인에서 해줘`, `main thread only`, or equivalent explicit opt-out, do not spawn subagents; report `Delegation: skipped user-opt-out`.
- If the user says `에이전트 쓰지마`, `no agents`, or equivalent explicit opt-out, do not spawn subagents; report `Delegation: skipped user-opt-out` and continue main-thread direct.
- Direct work is allowed when the user explicitly opts out of agents.

Non-trivial work means multi-step, multi-file, architecture/workflow/plugin/harness change, backend/frontend behavior change, test strategy, review, verification, CI, release-sensitive, or unclear approval-boundary work.

Read-only clarification helpers such as `goal-boundary` and `intake-planner` also require runtime delegation permission when implemented as actual subagent calls. Without permission, the main thread may perform Socratic clarification and role-based planning, but must not report simulated work as `Agents Used`.

## Strict Workflow Order

Run stages in order unless the user narrows the task:

1. `Requirement Intake`: main thread records request, assumptions, risks, and initial ambiguity.
2. `Socratic Clarification`: main thread asks targeted questions before implementation or worker handoff.
3. `Ambiguity Recalculation`: main thread recalculates per-feature ambiguity and average ambiguity.
4. `Goal Boundary Confirmation`: confirm goal, non-goals, success criteria, stop condition, allowed paths, forbidden paths, validation, git, TaskResult, and risk gates.
5. `Agent Route Planning`: discover repo-local agents, map roles, split accepted goals into feature slices, decide serial or parallel route, and check delegation permission.
6. `Subagent Handoff`: call allowed subagents only after clarification is satisfied and handoff inputs are explicit.
7. `Worker Implementation`: call feature-scoped specialists and feature workers only when slice scope is settled, permission exists, and dependencies allow serial or parallel execution.
8. `Review Agent`: call feature-slice scoped reviewer agents after meaningful diff or earlier as read-only risk review when allowed.
9. `Verification Agent`: call verification runner for build/test/script/smoke evidence when allowed.
10. `Main Thread Final Summary`: integrate results and report changes, verification, delegation, skipped agents, git, and TaskResult.

Legacy phase mapping:

- `Phase 0 - Workflow Guardrails` maps to Requirement Intake risk gates.
- `Phase 1 - Goal Boundary` maps to Socratic Clarification, Ambiguity Recalculation, and Goal Boundary Confirmation.
- `Phase 2 - Intake Planning` maps to Agent Route Planning.
- `Phase 3 - Implementation Coordination` maps to Agent Route Planning, feature slicing, and Subagent Handoff.
- `Phase 4 - Specialist Analysis` maps to feature-specific planner handoff.
- `Phase 5 - Bounded Implementation` maps to Worker Implementation.
- `Phase 6 - Review` maps to Review Agent and must route review by feature slice and reviewer perspective.
- `Phase 7 - Verification` maps to Verification Agent.
- `Phase 8 - Git Operation` is allowed only when the user explicitly requested git work.

## Phase Handoff Contract

Every handoff phase must state `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.

Do not enter the next phase until current phase output satisfies its `Output Contract` and `Handoff Gate`.

Handoff Gate must include accepted prior result summary, unresolved risks, open questions or `none`, average ambiguity %, goal alignment result, delegation permission status, and whether the next phase may proceed.

Handoff prompt must include `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.

Do not hand off to the next agent until previous agent output is explicit, bounded, and usable as the next input contract.

Previous agent output is clear only when it includes: role, scope, `Findings`, `Changes`, `Risks`, `Verify`, `Next`, affected paths, and open questions or `none`.

Each handoff prompt must start with `Prior result accepted:` plus a short summary of the previous agent result and any unresolved risks.

## Mandatory Socratic Checkpoint

Ask at least one Korean Socratic question unless a skip condition applies.

Socratic clarification must cover:

- user's actual purpose;
- success criteria;
- scope;
- non-goals;
- priorities;
- allowed files or areas;
- validation criteria;
- git, commit, and TaskResult expectation;
- destructive, secret, network, or production risks.

Ask:

1. State the current best assumption first.
2. State current ambiguity percentage and target average ambiguity `<= 8%`.
3. Ask 1-3 Korean questions that expose priority, tradeoff, non-goal, affected surface, output location, validation standard, git/release expectation, or stop condition.
4. Prefer contrastive questions that let the user include one thing and exclude another.
5. Stop implementation and worker handoff until the user answers, unless the task is a direct answer or trivial one-file fix with no unresolved ambiguity.

On user answer:

- After every user answer, restate the updated goal boundary, recalculate each feature ambiguity %, recalculate average ambiguity %, and check whether the answer still aligns with the active goal.
- Recalculate ambiguity percentage for each active feature goal and the average ambiguity after every answer.
- Check goal alignment after every answer.
- Before moving to any next work stage, explicitly tell the user the updated feature ambiguity %, average ambiguity %, goal alignment result, and next stage.
- Before moving to the next stage, explicitly show the user the recalculated ambiguity and goal alignment result.
- Continue this answer -> reassess -> ask loop until average ambiguity is `<= 8%`.
- Print `Socratic: skipped` with the exact skip condition when skipped.
- Print `Socratic: satisfied` only when average ambiguity is `<= 8%` or remaining ambiguity is explicitly moved to Out Of Scope or Todo.

## Agent Selection Rules

Match agents by discovered `name` + `description`, not filename.

Prefer capabilities when present: workflow or guardrails, goal or boundary, intake or planner, feature slicer, implementation or coordinator, service or backend template, frontend or UI policy, TDD or test, reference or audit, docs/harness specialist, code reviewer or review, backend reviewer, frontend reviewer, test reviewer, docs/harness reviewer, verification or runner, and git operator.

## Parallelization Rules

Use parallel work only after Goal Boundary Confirmation and Agent Route Planning. Parallel outputs must be independent, or read-only, or post-implementation reviewers inspecting the same completed diff without editing it.

Safe parallel groups:

- Pre-implementation backend analysis: service-template + TDD/test.
- Pre-implementation UI/API analysis: frontend/UI + service-template + TDD/test.
- Pre-implementation structure analysis: reference/audit + TDD/test.
- Feature-scoped specialist planning: service-template + frontend-ui + tdd-test + reference-auditor + docs-harness-specialist only when each receives a different accepted feature slice or distinct read-only perspective.
- Worker implementation: backend-worker + frontend-worker + test-worker + docs-harness-worker only when write sets are disjoint and contracts are stable.
- Post-implementation review: one or more feature-slice scoped reviewers. Use `backend-reviewer` for backend/API/domain slices, `frontend-reviewer` for UI/client slices, `test-reviewer` for test/validation slices, `docs-harness-reviewer` for plugin/docs/harness slices, `code-reviewer` for broad defect scan, and reference/auditor when architecture or external API boundaries changed.
- Post-implementation verification: verification-runner can run in parallel only when its command is non-mutating and independent of review outputs.

Review parallelism:

- Run reviewers in parallel only when they are read-only and each reviewer has a bounded feature slice or distinct perspective.
- Do not ask every reviewer to inspect the whole diff.
- Serialize review when one reviewer output changes another reviewer's input contract.
- Each reviewer handoff must include feature slice, allowed paths, forbidden paths, changed files or diff scope, success criteria, unresolved risks, validation evidence, and stop condition.

If agent questions, evidence duties, or write sets overlap, merge them, serialize them, or skip the duplicate role with `Delegation: skipped coupled`.

While subagents are running, do not duplicate their implementation scope in the main thread.

## Output Contract

For orchestration turns, include:

- `Phase`: numbered workflow phase and phase name.
- `Agent`: called agent name and role.
- `Purpose`: why this phase/agent exists.
- `Input Contract`: accepted prior result used as input.
- `Output Contract`: required result fields for next phase.
- `Handoff Gate`: pass/fail, unresolved risks, open questions or `none`, ambiguity %, goal alignment, delegation permission, and next phase permission.
- `Stage`: current workflow stage.
- `Discovered`: relevant agents/skills found.
- `Route`: ordered stages, including any safe parallel read-only groups.
- `Workers`: feature worker agents, feature slice ownership, parallel eligibility, and serial order when needed.
- `Specialists`: feature-scoped specialist agents, feature slice ownership, planning perspective, and skipped specialist reasons.
- `Socratic`: asked, satisfied, skipped with reason, or blocked waiting for user answer.
- `Ambiguity`: before/after per feature and average.
- `Delegation Permission`: explicit, not explicit, user-opt-out, host-policy, or unavailable.
- `Delegation`: spawned subagents, skipped eligible roles with concrete reasons, utilization floor satisfied or not, and fallback status.
- `Agents Used`: actual spawned agents only.
- `Agents Skipped`: spawnable but skipped agents and reasons.
- `Gate`: clarification, approval, test, verification, or git requirement.
- `Action`: what happens next.

Before the final user response, report:

- `Agents Used`: agents called, role, purpose, and whether each result was reflected.
- `Agents Skipped`: skipped eligible agents and short reason, or `none`.
- `Agent Results Reflected`: yes/no; if no, state why.
- `Socratic`: asked/satisfied/skipped.
- `Ambiguity`: before/after average and any remaining feature ambiguity.
- `Delegation Permission`: explicit, not explicit, user-opt-out, host-policy, or unavailable.
- `Main Thread Work`: integration, non-overlapping verification, cleanup, or unblock work performed directly.
- `Review/Verification Evidence`: reviewer findings and validation command outcomes.
- `Files Changed`: changed paths.
- `Git`: `not requested; git-operator not used` unless the user explicitly requested commit, push, PR, branch, merge, reset, clean, or worktree work.
- `TaskResult`: `not requested; not created` unless the user explicitly requested it.

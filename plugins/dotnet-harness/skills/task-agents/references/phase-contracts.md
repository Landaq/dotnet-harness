# Phase Contracts

## Agent-First Orchestration

Main thread is the orchestrator, not the default implementer, for non-trivial work when task-agents is active.

Agent-first handoff is the default for non-trivial dotnet-harness work. The user does not need to explicitly request subagent handoff.

Agent-first means planning, implementation, review, and verification should be delegated to discovered repo-local agents whenever the task is non-trivial and subagent capability is available.

When task-agents is active, the main thread is a coordinator/reporter, not the default implementer.

Subagents own staged analysis, implementation, review, and verification. Main thread edits are exceptions and must be reported.

Each subagent output must be treated as the input contract for the next stage.

Run task-agent routing before non-trivial implementation starts. If the user explicitly says `/feedback`, `task-agents`, `에이전트를 활용`, `에이전트들이 전반적으로 수행`, `agents overall`, `run agents`, or similar wording, treat the request as agent-first orchestration instead of agent-assisted review.

Direct main-thread edits are allowed only for small fixes, integration of agent output, or non-overlapping unblock work.

Automatic trigger and opt-out:

- If the user explicitly invokes `@dotnet-harness` for non-trivial work, treat the request as task-agents active and agent-first unless the user explicitly opts out of agents.
- Treat the request as agent-first when the newest user message mentions `@dotnet-harness`, `$dotnet-harness`, `dotnet-harness`, `task-agents`, `/feedback`, `에이전트`, `agents overall`, `run agents`, or asks for non-trivial work.
- Non-trivial work means multi-step, multi-file, architecture/workflow/plugin/harness change, backend/frontend behavior change, test strategy, review, verification, CI, release-sensitive, or unclear approval-boundary work.
- If the user says `에이전트 쓰지마`, `no agents`, or equivalent explicit opt-out, do not spawn subagents; report `Delegation: skipped user-opt-out` and continue main-thread direct.
- Main-thread direct work is allowed for a direct answer, status check, trivial one-file fix, or explicit agent opt-out.

If no agent is called, report why briefly with `Delegation: skipped <reason>`.

## Strict Staged Handoff Order

Strict staged handoff order:

1. `Phase 0 - Workflow Guardrails`: call `workflow-guardrails`; purpose = safety, approval, destructive/git/secret/production gates.
2. `Phase 1 - Goal Boundary`: call `goal-boundary`; purpose = goal, non-goals, success criteria, stop condition, Socratic ambiguity gate.
3. `Phase 2 - Intake Planning`: call `intake-planner`; purpose = work units, affected paths, validation candidates, agent route.
4. `Phase 3 - Implementation Coordination`: call `implementation-coordinator`; purpose = phase plan, specialist assignment, safe parallel/serial handoff order.
5. `Phase 4 - Specialist Analysis`: call read-only specialists such as `service-template`, `frontend-ui`, `tdd-test`, or `reference-auditor`; purpose = domain-specific constraints before edits.
6. `Phase 5 - Bounded Implementation`: call feature-specific worker agents only when write scope is settled; purpose = code/doc/test change in allowed paths.
7. `Phase 6 - Review`: call `code-reviewer` or feedback specialist; purpose = diff risk, regression, test gap, boundary violation review.
8. `Phase 7 - Verification`: call `verification-runner`; purpose = build/test/script/smoke evidence and final validation.
9. `Phase 8 - Git Operation`: call `git-operator` only when user explicitly requested git work; purpose = stage, commit, tag, push, PR, branch/worktree work.

Phase handoff contract:

- Every phase must state `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.
- Do not enter next phase until current phase output satisfies its `Output Contract` and `Handoff Gate`.
- Handoff Gate must include accepted prior result summary, unresolved risks, open questions or `none`, and whether the next phase may proceed.
- Handoff prompt must include `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.

## Mandatory Socratic Checkpoint

Mandatory Socratic Checkpoint:

Ask at least one Korean Socratic question unless a skip condition applies.

Ask:

1. State the current best assumption first.
2. State current ambiguity percentage and target average ambiguity `<= 8%`.
3. Ask 1-3 Korean questions that expose priority, tradeoff, non-goal, affected surface, output location, validation standard, git/release expectation, or stop condition.
4. Prefer contrastive questions that let the user include one thing and exclude another.
5. Stop all planning and implementation until the user answers.

On user answer:

- After every user answer, restate the updated goal boundary, recalculate each feature ambiguity %, recalculate average ambiguity %, and check whether the answer still aligns with the active goal.
- Recalculate ambiguity percentage for each active feature goal and the average ambiguity after every answer.
- Check goal alignment after every answer.
- Before moving to any next work stage, explicitly tell the user the updated feature ambiguity %, average ambiguity %, goal alignment result, and next stage.
- Before moving to the next stage, explicitly show the user the recalculated ambiguity and goal alignment result.
- Continue this answer -> reassess -> ask loop until average ambiguity is `<= 8%`.
- Print `Socratic: skipped` with the exact skip condition when skipped.
- Print `Socratic: satisfied` when satisfied.

## Routing Order

Run stages in order unless user narrows task:

1. Safety gate.
2. Goal boundary.
3. Intake planning.
4. Implementation coordination.
5. Subagent delegation.
6. Read-only parallel specialist analysis.
7. Serial implementation.
8. Post-implementation review.
9. Verification.
10. Explicit git operation.

Subagent delegation must enforce the Agent Execution Contract.

If agent questions, evidence duties, or write sets overlap, merge them, serialize them, or skip the duplicate role with `Delegation: skipped coupled`.

While subagents are running, do not duplicate their implementation scope in the main thread.

## Agent Selection Rules

Match agents by discovered `name` + `description`, not filename.

Prefer capabilities when present: workflow or guardrails, goal or boundary, intake or planner, implementation or coordinator, service or backend template, frontend or UI policy, TDD or test, reference or audit, code reviewer or review, verification or runner, and git operator.

## Parallelization Rules

Use parallel work only when outputs are independent and read-only, or when post-implementation reviewers inspect the same completed diff without editing it.

Safe parallel groups:

- Pre-implementation backend analysis: service-template + TDD/test.
- Pre-implementation UI/API analysis: frontend/UI + service-template + TDD/test.
- Pre-implementation structure analysis: reference/audit + TDD/test.
- Post-implementation review: code-reviewer + reference/auditor when architecture boundaries changed.
- Post-implementation verification: verification-runner can run in parallel only when its command is non-mutating and independent of review outputs.

## Output Contract

For orchestration turns, include:

- `Phase`: numbered workflow phase and phase name.
- `Agent`: called agent name and role.
- `Purpose`: why this phase/agent exists.
- `Input Contract`: accepted prior result used as input.
- `Output Contract`: required result fields for next phase.
- `Handoff Gate`: pass/fail, unresolved risks, open questions or `none`, and next phase permission.
- `Stage`: current workflow stage.
- `Discovered`: relevant agents/skills found.
- `Route`: ordered stages, including any safe parallel read-only groups.
- `Workers`: feature worker agents, feature slice ownership, parallel eligibility, and serial order when needed.
- `Socratic`: questions asked, skipped with reason, or blocked waiting for user answer.
- `Delegation`: spawned subagents, skipped eligible roles with concrete reasons, utilization floor satisfied or not, and fallback status.
- `Gate`: clarification, approval, test, verification, or git requirement.
- `Action`: what happens next.

Before the final user response, report:

- `Agents Used`: agents called, role, purpose, and whether each result was reflected.
- `Agents Skipped`: skipped eligible agents and short reason, or `none`.
- `Agent Results Reflected`: yes/no; if no, state why.
- `Main Thread Work`: integration, non-overlapping verification, cleanup, or unblock work performed directly.
- `Review/Verification Evidence`: reviewer findings and validation command outcomes.
- `Files Changed`: changed paths.
- `Git`: `not requested; git-operator not used` unless the user explicitly requested commit, push, PR, branch, merge, reset, clean, or worktree work.
- `TaskResult`: `not requested; not created` unless the user explicitly requested it.

# Workflow Agent Specialization Design

## Context

The repository currently has a repo-local task orchestration model under `.codex`.

Existing agents:

- `01-workflow-guardrails.toml`
- `02-service-template.toml`
- `03-frontend-ui.toml`
- `04-tdd-test.toml`
- `05-reference-auditor.toml`

Existing orchestration skill:

- `.codex/skills/task-agents/SKILL.md`

The current model already discovers agents and skills from the local repository instead of hardcoding project identity. This design preserves that rule while adding workflow-stage specialization.

## Approved Direction

Use standard workflow specialization.

Keep the existing domain and quality agents. Add five workflow-stage agents:

- `06-intake-planner.toml`
- `07-implementation-coordinator.toml`
- `08-code-reviewer.toml`
- `09-verification-runner.toml`
- `10-git-operator.toml`

Keep `01-workflow-guardrails.toml`, but narrow its role to safety and approval gates. Planning responsibility moves to the new intake and coordination agents.

## Agent Responsibilities

### Existing Agents

`workflow-guardrails` remains the first safety gate. It identifies destructive actions, git publishing, database changes, secret handling, production access, and unclear approval boundaries.

`service-template` remains responsible for backend service boundaries, DDD layer separation, public contracts, and service test placement.

`frontend-ui` remains responsible for Blazor UI policy, MudBlazor-first decisions, approved DevExpress BI use, render mode impact, and `Web.Client` safety.

`tdd-test` remains responsible for Red-Green-Refactor sequencing, test level selection, and layer-specific test placement.

`reference-auditor` remains responsible for architecture and process audits against repository baseline decisions.

### New Workflow Agents

`intake-planner` interprets the user request into work units, success criteria, affected paths, expected outputs, and open questions. It does not override the safety gate.

`implementation-coordinator` decides which domain agents and skills apply, whether read-only parallel analysis is useful, and the final serial implementation order.

`code-reviewer` reviews completed diffs for bugs, regressions, excessive scope, missing tests, and boundary violations. Findings come before summaries.

`verification-runner` selects the smallest command or inspection that proves the claim, records actual outcomes, and decides whether the work is verified.

`git-operator` handles stage, commit, push, and PR preparation only when the user explicitly requests those actions. It must preserve narrow staging and avoid unrelated dirty-tree changes.

## Routing Flow

The updated `task-agents` flow should be:

1. `workflow-guardrails`: safety and approval gate.
2. `intake-planner`: request interpretation and success criteria.
3. `implementation-coordinator`: agent selection and parallelization decision.
4. Read-only parallel specialist analysis when useful.
5. `implementation-coordinator`: merge specialist results into one execution order.
6. Serial implementation through the relevant domain and test agents.
7. Parallel post-implementation review when useful.
8. `implementation-coordinator`: merge review and verification outcomes.
9. `git-operator`: explicit user-approved git work only.

Agent matching must continue to use discovered `name` and `description` fields instead of filename-only or project-name hardcoding.

## Parallelization Model

Parallel work is allowed for read-only analysis and post-implementation review. It is not allowed for simultaneous edits to the same files.

Recommended pre-implementation parallel checks:

- Backend work: `service-template` and `tdd-test`.
- UI/API work: `frontend-ui`, `service-template`, and `tdd-test`.
- Structure or governance work: `reference-auditor` and `tdd-test`.

Recommended post-implementation parallel checks:

- `code-reviewer` for diff risks.
- `verification-runner` for validation commands and result interpretation.
- `reference-auditor` when architecture boundaries or baseline decisions changed.

Avoid parallelization for:

- Multiple agents editing the same files.
- `git-operator` running while implementation or review is still active.
- Implementation before `workflow-guardrails` resolves approval constraints.
- Test-failure remediation without first identifying the cause.

## File Change Scope

Implementation should be limited to:

- Add `.codex/agents/06-intake-planner.toml`.
- Add `.codex/agents/07-implementation-coordinator.toml`.
- Add `.codex/agents/08-code-reviewer.toml`.
- Add `.codex/agents/09-verification-runner.toml`.
- Add `.codex/agents/10-git-operator.toml`.
- Update `.codex/agents/01-workflow-guardrails.toml` to narrow its description and instructions.
- Update `.codex/skills/task-agents/SKILL.md` to describe the new routing flow and parallelization model.
- Update `.codex/skills/task-agents/agents/openai.yaml` only if display metadata needs to reflect the new workflow.

Do not change:

- Application code.
- Solution files.
- Existing domain skill behavior.
- `project-structure-setup` agent mapping.
- Git state beyond the approved design document commit unless the user explicitly asks.

## Verification Criteria

The implementation plan should include checks that:

- `.codex/agents` contains ordered files `01` through `10`.
- Every new TOML agent has `name`, `description`, `developer_instructions`, `model_reasoning_effort`, and `sandbox_mode`.
- `workflow-guardrails` no longer owns broad planning responsibility.
- `task-agents` documents the new routing sequence.
- `task-agents` documents read-only parallel analysis and review.
- Discovery-first routing remains based on agent and skill metadata.
- `quick_validate.py` passes for all repo-local skill folders when available.

## Acceptance

The change is successful when future multi-step work can be routed through:

`workflow-guardrails -> intake-planner -> implementation-coordinator -> specialist analysis -> implementation -> code-reviewer/verification-runner -> optional git-operator`

The system should be more explicit about who plans, who coordinates, who reviews, who verifies, and who performs git operations, while keeping actual implementation edits serial and controlled.

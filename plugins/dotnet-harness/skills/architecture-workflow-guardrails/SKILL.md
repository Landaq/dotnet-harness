---
name: architecture-workflow-guardrails
description: "Guide request clarification, ambiguity checks, plan flow, and approval rules for backend, frontend, and complex full-stack changes before coding."
---

# Architecture Workflow Guardrails

Use before implementation when request touches feature, cross-layer refactor, service boundary, API/Gateway/FrontEnd/Aspire workflow.

## Request Classification

- Complex work: threshold 13%
- Backend work: threshold 5%
- Frontend work: threshold 5%

If ambiguity above threshold, ask max 3 questions before code.

## Clarification Rule

- Number questions.
- Mark recommendation with `(Recommended)`.
- State current ambiguity + target before questions.
- Recalculate ambiguity after each user answer.
- No implementation until ambiguity below threshold.

## Common Decision Sets

- Service scope: new service vs extend existing service.
- Contract impact: internal-only API or external contract included.
- UI scope: minimum screens vs full CRUD.

## Common Workflow

1. Confirm scope and ambiguity.
2. Ask up to 3 questions if needed.
3. Plan affected layers + test strategy.
4. Create plan artifact only when user explicitly asks.
5. Request approval when needed.
6. Execute TDD by ordered layers.

## Safety Rules

- No destructive Git without explicit user request.
- Branch/worktree approval first.
- Migration, secret handling, destructive cleanup, commit, push, merge need explicit consent.

## Required Outputs

- Architecture plan
- Test plan by layer
- Risk/approval list
- Result summary with validation notes

See [workflow-guide.md](references/workflow-guide.md).

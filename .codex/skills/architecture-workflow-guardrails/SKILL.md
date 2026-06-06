---
name: architecture-workflow-guardrails
description: "Guide request clarification, ambiguity checks, plan flow, and approval rules for backend, frontend, and complex full-stack changes before coding."
---

# Architecture Workflow Guardrails

Use this skill before implementation when user requirements include:
- new feature
- refactor across layers
- service boundary changes
- API/Gateway/FrontEnd/Aspire workflow changes

## Request Classification

- Complex work: threshold 13%
- Backend work: threshold 5%
- Frontend work: threshold 5%

When current ambiguity is above the threshold, ask exactly up to 3 clarifying questions before coding.

## Clarification Rule

- Questions are numbered.
- Mark recommended option with `(Recommended)`.
- State current ambiguity and target threshold before asking questions.
- Recalculate ambiguity after each user answer.
- Do not implement if ambiguity is not reduced below threshold.

## Common Decision Sets

- Service scope: new service vs extend existing service.
- Contract impact: internal-only API or external contract included.
- UI scope: minimum screens vs full CRUD.

## Common Workflow

1. Confirm scope and ambiguity.
- 2. Ask up to 3 questions if needed.
- 3. Produce implementation plan with affected layers and test strategy.
- 4. Create or update `docs/wkTask/Specs/{yyMMdd}_{Summary}_plan.md` when required.
- 5. Request user approval for work to proceed.
- 6. Execute with TDD and tests in ordered layers.

## Safety Rules

- Do not execute destructive Git commands without explicit user request.
- Keep branch and worktree actions approval-first.
- Keep migration, secret handling, destructive file cleanup, commit, push, and merge actions behind explicit consent.

## Required Outputs

- Architecture plan
- Test plan by layer
- Risk/approval list
- Result summary with validation notes

See [workflow-guide.md](references/workflow-guide.md).

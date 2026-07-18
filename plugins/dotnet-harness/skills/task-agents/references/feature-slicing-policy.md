# Feature Slicing Policy

## Purpose

Feature slicing prevents one broad agent from owning an entire multi-area task.

Use `feature-slicer` after Socratic clarification and before planner, worker, reviewer, or verification handoff when work spans multiple domains, file groups, validation boundaries, or implementation workers.

## Slice Contract

Each feature slice must define:

- slice name;
- purpose;
- non-goals;
- allowed paths;
- forbidden paths;
- expected changed files;
- dependency order;
- parallel eligibility;
- validation evidence;
- reviewer perspective;
- stop condition.

Do not create speculative slices outside the user's goal.

## Specialist Routing

Use the smallest specialist set:

- `service-template`: backend/API/domain/infrastructure/service slices.
- `frontend-ui`: Blazor/UI/client/rendering slices.
- `tdd-test`: tests, coverage, regression, smoke validation slices.
- `reference-auditor`: external reference or architecture comparison slices.
- `docs-harness-specialist`: plugin, skill, agent, script, scaffold, install, upgrade, docs, release slices.

Skip a specialist only with a concrete reason: trivial, coupled, already-covered, unavailable, host-policy, no-explicit-agent-request, or user-opt-out.

## Parallel Specialist Planning

Run specialists in parallel only when:

- each specialist receives a different feature slice or distinct read-only perspective;
- no specialist output changes another specialist's input contract;
- no unresolved public contract blocks another slice;
- specialist output can be integrated without file edits.

Serialize specialists when:

- backend contract determines frontend or test planning;
- scaffold or package changes determine generated code paths;
- validation strategy depends on implementation order;
- slices share files, public contracts, migrations, package files, solution files, runtime state, or release state.

## Handoff

Specialist handoff must include:

```text
Prior result accepted:
Role:
Feature Slice:
Goal:
Non-goals:
Allow:
Deny:
Need:
Verify:
Stop:
No git unless explicit.
Return:
Findings:
Changes:
Risks:
Verify:
Next:
```

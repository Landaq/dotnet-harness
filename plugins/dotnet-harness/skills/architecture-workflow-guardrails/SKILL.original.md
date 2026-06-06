---
name: architecture-workflow-guardrails
description: "Apply Codex workflow guardrails: ambiguity handling, workflow classification, 3-question pre-implementation checks, and approval-safe execution sequence."
---

# Architecture Workflow Guardrails

Use this skill when request scope is broad, cross-layer, or ambiguous.

## Work classification

- **Complex task**: multi-layer or architecture changes; ambiguity target <= 13%.
- **Backend task**: `src/BackEnd`, `Aspire`, API/db/auth/Gateway changes; ambiguity target <= 5%.
- **Frontend task**: `src/FrontEnd` changes; ambiguity target <= 5%.

When ambiguity exceeds target, run clarification before implementation.

## Socratic question format

- Ask at most 3 items per turn.
- Number as `1.`, `2.`, `3.`.
- Mark the recommended option with `(Recommended)`.
- Recompute ambiguity before moving forward.

## Workflow steps

1. Clarify scope and acceptance criteria.
2. Confirm project/service boundaries and impacted layers.
3. Create or validate plan before code.
4. Define test scope before implementation.
5. Implement in sequence with review gates.
6. Report remaining risks before commit/push.

## Mandatory constraints

- Never proceed to destructive actions without explicit user approval.
- Do not commit, push, merge, branch, worktree, reset, or clean without approval.
- Keep sensitive info out of notes and outputs (tokens, credentials, connection strings, personal keys).

## Plan and result naming

- If a plan is requested, follow `docs/wkTask/Specs/{yyMMdd}_{Summary}_plan.md`.
- Create results as `docs/wkTask/Results/{yyMMdd}_{Summary}_result.html`.
- For this repo, prioritize `Rev04.slnx` in all validation references.

## Approval boundaries

- If ambiguous:
  - request clarification in Korean for missing decisions.
  - pause implementation until the user confirms.

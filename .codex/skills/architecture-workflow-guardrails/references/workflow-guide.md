# Workflow Guardrails Reference

- Classify tasks by impact:
  - Complex: cross-layer / architecture changes (target ambiguity <= 13%)
  - Backend: DB, API, Gateway, Aspire changes (target ambiguity <= 5%)
  - Frontend: UI/UX Blazor changes (target ambiguity <= 5%)
- Ask up to 3 questions when ambiguous.
- Keep recommendation labels with `(Recommended)`.
- Require explicit approval for branch/worktree creation, commits, pushes, merges, resets, or destructive cleanup.
- Use `docs/wkTask/Specs/{yyMMdd}_{Summary}_plan.md` and `docs/wkTask/Results/{yyMMdd}_{Summary}_result.html` when plan-driven flow is requested.

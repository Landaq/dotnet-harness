# Workflow Guardrail Reference

- Classify requests by work type and ambiguity threshold:
  - Complex work: 13%
  - Backend work: 5%
  - Frontend work: 5%
- Ask at most 3 clarifying items when above threshold.
- Recommended option must be shown with `(Recommended)`.
- Keep destructive Git actions outside scope unless explicitly approved.
- For plan-file mode, implementation can begin after user plan approval.
- Prefer explicit spec naming under `docs/wkTask/Specs/{yyMMdd}_{Summary}_plan.md`.
- Include verification commands and risk list before execution.

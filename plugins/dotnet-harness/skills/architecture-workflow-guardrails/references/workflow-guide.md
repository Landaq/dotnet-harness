# Workflow Guardrail Reference

- Classify requests by work type and ambiguity threshold:
  - Complex work: 13%
  - Backend work: 5%
  - Frontend work: 5%
- Ask at most 3 clarifying items when above threshold.
- Recommended option must be shown with `(Recommended)`.
- Keep destructive Git actions outside scope unless explicitly approved.
- For explicit plan-file mode, implementation can begin after user plan approval.
- Do not create plan files by default; create a named plan artifact only when the user explicitly asks for one.
- Include verification commands and risk list before execution.

# Workflow Modes

Select one workflow mode before routing:

- `lightweight`: default for trivial or small tasks. Use for direct answers, status checks, narrow one-file fixes, mechanical doc edits, or low-risk validation. Ask at most one clarification question. Keep phase contracts internal unless a gate fails. Do not spawn Phase 5 worker agents. Final reporting is short: changes, verification, delegation status, git status, and TaskResult status.
- `standard`: default for non-trivial work. Use Phase 0 through Phase 8, call only agents that are needed, and expose concise phase transitions. Phase 5 worker agents are allowed only when requirements are settled. Parallel Phase 5 workers are allowed only for independent feature slices.
- `deep`: use when the user explicitly asks for deep review/planning, or when the task is release-sensitive, scaffold-changing, architecture-changing, high-risk, destructive-adjacent, security/auth/data-sensitive, or has unclear acceptance boundaries. Use the full Socratic checkpoint, full handoff gates, review, and verification reporting.

Mode selection rules:

- Trivial or small work -> `lightweight`.
- Non-trivial work -> `standard`.
- Explicit deep/release/scaffold/architecture/high-risk work -> `deep`.

Mode reporting:

- In `lightweight` and `standard`, ambiguity percentage is an internal routing signal. Tell the user only the remaining uncertainty in natural language unless a gate blocks progress.
- In `deep`, report ambiguity percentage, phase contracts, input/output contracts, and handoff gates.
- If the selected mode changes mid-task, state the old mode, new mode, and reason before continuing.

Mode-specific final reporting:

- `lightweight`: include `Agents Used`, `Agents Skipped`, `Main Thread Work`, `Review/Verification Evidence`, `Files Changed`, `Git`, and `TaskResult` only. Omit full phase and handoff tables unless a gate failed.
- `standard`: include concise phase summary, selected agents, skipped agents, worker eligibility, verification evidence, changed files, git status, and TaskResult status.
- `deep`: include full phase/input/output/handoff-gate reporting, Socratic status, worker partition, review findings, verification evidence, changed files, git status, and TaskResult status.
